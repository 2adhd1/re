# MCSR setup bootstrap

These eight entry points fetch only the selected profile from the pinned
`diamondgather1n/mcsr-setup` commit, then run its existing installer.

```bash
git clone -q --depth=1 https://github.com/2adhd1/re ~/re
~/re/MNLmcsrWL.sh
```

For development, override the pinned source commit with `MCSR_SETUP_REF`.
The downloaded installer checkout is placed at `~/mcsr-setup`, because that is
the existing installer's guarded working path. It is removed by the installer
only after a successful installation; failed installs retain it for diagnosis.
