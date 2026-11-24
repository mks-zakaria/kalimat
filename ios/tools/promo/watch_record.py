"""Event-driven screen recording: follows a UI test's event log and records one simulator video per
segment, starting on a start event and stopping on a stop event. No timestamp maths: the test writes the
start line before it acts, so each file holds exactly that segment (the recorder needs < 1 s to start;
the tests pause 3 s after logging a start).

    python3 watch_record.py <sim id> <events.log> <out dir> <done-flag file> START=END [CLUE=SOLVED COMPLETE=END]

Writes <out dir>/seg-NNN.mp4 and <out dir>/segments.tsv (file, start line, stop line). Ends when the
done-flag file exists and no segment is open. The same file is used by the Kalimat promo pipeline.
"""
import os, subprocess, sys, time
from pathlib import Path

sim, log, out, done = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3]), Path(sys.argv[4])
pairs = dict(p.split("=") for p in sys.argv[5:])           # start event -> stop event
out.mkdir(parents=True, exist_ok=True)
tsv = (out / "segments.tsv").open("a")
pos, n, rec, opened, stop_on = 0, len(list(out.glob("seg-*.mp4"))), None, "", None

def start(line):
    global rec, n, opened, stop_on
    n += 1
    f = out / f"seg-{n:03d}.mp4"
    rec = subprocess.Popen(["xcrun", "simctl", "io", sim, "recordVideo", "--codec=h264", "--force", str(f)],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    opened, stop_on = line, pairs[line.split()[1]]
    rec.file = f

def stop(line):
    global rec
    # XCUITest's tap returns before the app has drawn its result: keep recording a moment after the stop
    # event (WATCH_STOP_DELAY seconds) so the last action is on screen.
    time.sleep(float(os.environ.get("WATCH_STOP_DELAY", "0.6")))
    rec.send_signal(2); rec.wait(timeout=60)
    tsv.write(f"{rec.file.name}\t{opened}\t{line}\n"); tsv.flush()
    print("segment", rec.file.name, "|", opened.split(" | ")[0].split(" ", 1)[1], flush=True)
    rec = None

while True:
    if log.exists():
        with log.open() as fh:
            fh.seek(pos); chunk = fh.read(); pos = fh.tell()
        for line in chunk.splitlines():
            parts = line.split(" | ")[0].split()
            if len(parts) < 2: continue
            kind = parts[1]
            if rec is None and kind in pairs: start(line)
            elif rec is not None and kind == stop_on: stop(line)
    if done.exists() and rec is None: break
    if done.exists() and rec is not None and time.time() - done.stat().st_mtime > 20: stop("forced"); break
    time.sleep(0.05)
