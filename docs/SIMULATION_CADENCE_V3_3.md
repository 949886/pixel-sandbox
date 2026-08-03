# Simulation Cadence V3.3

## Problem fixed

V3.2 used `simulation_repaint_hz` as both the native simulation rate and the texture upload rate. The PC profile therefore advanced each canvas at only 15 Hz, and the mobile profile at 8 Hz. A shared round-robin could reduce an individual chunk even further.

## New scheduling model

- Native `SandSimulation.step()` and visual repaint are independently scheduled.
- The player chunk is always serviced first each rendered frame.
- PC foreground simulation: 60 Hz; neighboring chunks: 12 Hz.
- Mobile foreground simulation: 30 Hz; neighboring chunks: 8 Hz.
- Repaint remains dirty-driven. A texture upload occurs only when native `is_dirty()` is true and the canvas repaint cap is due.
- Streaming warmup, texture activation and collision building run after foreground simulation, so loading cannot steal the visible simulation slot.
- Missed simulation periods do not trigger catch-up bursts; one native step is performed per scheduler visit.

## Runtime profile fields

- `simulation_hz`: foreground/current-player chunk native step rate.
- `background_simulation_hz`: active neighboring chunk native step rate.
- `simulation_repaint_hz`: maximum dirty texture upload rate. Neighbor repaint rate is automatically capped to its simulation rate.

Press F1 to inspect the configured foreground/background/render rates and the number of simulation ticks completed in the latest frame.
