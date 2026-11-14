# Queue for the IR camera, patched into howdy's compare.py.
#
# Two face scans cannot share the camera, and Bitwarden asks polkit twice at
# once. Scans take a lock and go one at a time. A scan that had to queue and
# sees the one ahead of it approve the same user is approved along with it:
# the face was checked while this request was already waiting, so a second
# scan would only cost time.

import fcntl
import os
import sys
import time

LOCK = "/run/howdy-camera.lock"
STAMPS = "/run/howdy"  # root-owned, so only a scan running as root can vouch


def _stamp(user):
    return os.path.join(STAMPS, "approved-" + user.replace("/", "_"))


def _approved_since(user, since):
    try:
        st = os.stat(_stamp(user))
    except OSError:
        return False
    return st.st_uid == 0 and st.st_mtime >= since


def open_camera(VideoCapture, config, user):
    """Wait for the camera, then open it. Exits 0 if the scan ahead approved."""
    global _lock
    _lock = open(LOCK)  # held until the process exits

    try:
        fcntl.flock(_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        queued_at = time.time()
        fcntl.flock(_lock, fcntl.LOCK_EX)
        if _approved_since(user, queued_at):
            sys.exit(0)

    # The previous scan may still be letting go of the device
    deadline = time.time() + 2
    while True:
        capture = VideoCapture(config)
        if capture.internal.isOpened() or time.time() > deadline:
            return capture
        capture.release()
        time.sleep(0.1)


def approved(user):
    """Record a successful scan for the ones queued behind it."""
    try:
        with open(_stamp(user), "w"):
            pass
    except OSError:
        pass  # not root (lock screen): nothing to vouch with
