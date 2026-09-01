"""
ACSM Input (libgourou) — a Calibre file-type plugin.

When you add an Adobe ``.acsm`` fulfillment token to Calibre, this plugin
fulfills it (downloads the real EPUB/PDF) and strips the ADEPT DRM, then hands
Calibre the clean book — so importing a Kobo/Adobe ``.acsm`` "just works".

Unlike the usual DeACSM plugin, this one does **no** crypto in Python. It shells
out to the native ``libgourou`` utilities (``acsmdownloader`` / ``adept_remove``
/ ``adept_activate``), which is what makes it painless on NixOS: no bundled
``oscrypto``, so none of the OpenSSL-3 version-parsing / ``libcrypto``-not-found
breakage that sinks DeACSM on this platform.

The three ``@…@`` placeholders below are substituted with absolute /nix/store
paths at build time by ``packages/calibre-acsm/default.nix``. If you are reading
an unbuilt copy they will still be literal ``@name@`` markers.
"""

import os
import glob
import shutil
import tempfile
import subprocess

from calibre.customize import FileTypePlugin


# --- Substituted at Nix build time (see default.nix) ------------------------
ACSMDOWNLOADER = "@acsmdownloader@"
ADEPT_REMOVE = "@adept_remove@"
ADEPT_ACTIVATE = "@adept_activate@"
# ---------------------------------------------------------------------------


class ACSMInputLibgourou(FileTypePlugin):

    name = "ACSM Input (libgourou)"
    description = (
        "Fulfill Adobe ACSM files and remove ADEPT DRM on import, using the "
        "native libgourou utilities. NixOS-friendly (no bundled oscrypto)."
    )
    supported_platforms = ["linux"]
    author = "Christopher Miller"
    version = (1, 0, 0)
    minimum_calibre_version = (5, 0, 0)

    file_types = set(["acsm"])
    on_import = True
    on_preprocess = True

    def initialize(self):
        # Calibre's add-book machinery only offers file types listed in
        # BOOK_EXTENSIONS. ``acsm`` is not built in, so register it here (this
        # runs once, when the plugin is loaded at startup).
        try:
            from calibre.ebooks import BOOK_EXTENSIONS

            if "acsm" not in BOOK_EXTENSIONS:
                BOOK_EXTENSIONS.append("acsm")
        except Exception:
            import traceback

            print("%s: could not register the acsm extension:" % self.name)
            traceback.print_exc()

    # -- helpers -------------------------------------------------------------

    def _adept_dir(self):
        """Persistent anonymous-ADEPT device directory, kept in Calibre's
        config so the same fingerprint is reused across imports."""
        from calibre.utils.config import config_dir

        return os.path.join(config_dir, "plugins", "acsm_adept")

    def _ensure_activation(self):
        """Return a path to a populated ``.adept`` directory, creating an
        anonymous activation the first time (or if it looks incomplete)."""
        d = self._adept_dir()
        needed = ["device.xml", "activation.xml", "devicesalt"]
        if os.path.isdir(d) and all(
            os.path.exists(os.path.join(d, f)) for f in needed
        ):
            return d

        # ``adept_activate`` insists the output directory does not already
        # exist, so clear any half-populated remnant first.
        if os.path.isdir(d):
            shutil.rmtree(d)
        os.makedirs(os.path.dirname(d), exist_ok=True)

        self._run([ADEPT_ACTIVATE, "-a", "-O", d],
                  "anonymous ADEPT device activation")
        return d

    def _run(self, argv, what):
        """Run a libgourou tool, raising a readable error on failure."""
        try:
            proc = subprocess.run(
                argv,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=True,
            )
        except FileNotFoundError:
            raise RuntimeError(
                "%s: %r not found — is the libgourou package installed and "
                "the plugin rebuilt with the right store paths?"
                % (self.name, argv[0])
            )
        except subprocess.CalledProcessError as e:
            out = (e.stdout or b"").decode("utf-8", "replace").strip()
            raise RuntimeError(
                "%s: %s failed (exit %d).\n%s" % (self.name, what, e.returncode, out)
            )
        return proc.stdout.decode("utf-8", "replace")

    # -- main entry point ----------------------------------------------------

    def run(self, path_to_ebook):
        # Only act on .acsm; anything else passes straight through so the
        # plugin is a no-op during ordinary conversions/imports.
        if not path_to_ebook.lower().endswith(".acsm"):
            return path_to_ebook

        adept = self._ensure_activation()

        # 1) Fulfill: download the real book into a scratch dir and let
        #    acsmdownloader name it (so we inherit the correct extension —
        #    usually .epub, sometimes .pdf).
        dl_dir = tempfile.mkdtemp(prefix="acsm_dl_")
        try:
            self._run(
                [ACSMDOWNLOADER, "-D", adept, "-O", dl_dir, path_to_ebook],
                "downloading the book from the ACSM token",
            )
            produced = [
                p
                for p in glob.glob(os.path.join(dl_dir, "*"))
                if os.path.isfile(p)
            ]
            if not produced:
                raise RuntimeError(
                    "%s: acsmdownloader produced no file. The ACSM token may "
                    "have expired — re-download it from the store." % self.name
                )
            encrypted = produced[0]
            ext = os.path.splitext(encrypted)[1].lower() or ".epub"

            # 2) Strip the ADEPT DRM into a Calibre-managed temp file, whose
            #    extension decides the format Calibre imports it as.
            clean = self.temporary_file(ext).name
            self._run(
                [ADEPT_REMOVE, "-D", adept, "-o", clean, encrypted],
                "removing ADEPT DRM",
            )
            return clean
        finally:
            shutil.rmtree(dl_dir, ignore_errors=True)
