use crate::model::{BEATS_PER_BAR, PPQ, Note, Output, Project, Track};
use midly::{
    Format, Header, MetaMessage, MidiMessage, Smf, Timing, TrackEvent, TrackEventKind,
};
use std::collections::HashMap;

pub fn parse_midi(data: &[u8]) -> Result<Project, String> {
    let smf = Smf::parse(data).map_err(|e| format!("MIDI parse error: {e}"))?;

    let src_ppq = match smf.header.timing {
        Timing::Metrical(ticks) => ticks.as_int() as f64,
        Timing::Timecode(_, _) => 480.0,
    };
    let scale = (PPQ as f64) / src_ppq;

    // テンポイベントを探索 (マイクロ秒/拍 -> BPM)
    let mut bpm = 120.0;
    for track in &smf.tracks {
        for event in track {
            if let TrackEventKind::Meta(MetaMessage::Tempo(t)) = event.kind {
                let us = t.as_int() as f64;
                if us > 0.0 {
                    let b = 60_000_000.0 / us;
                    if (20.0..=500.0).contains(&b) {
                        bpm = b.round();
                        break;
                    }
                }
            }
        }
    }

    let mut parsed_tracks = Vec::new();
    let mut max_tick: u32 = 0;
    let mut note_id_counter = 1;

    for (t_idx, track) in smf.tracks.iter().enumerate() {
        let mut track_name = String::new();
        let mut program: u8 = 0;
        let mut channel: u8 = 0;
        let mut current_tick: u64 = 0;

        // (channel, pitch) -> (start_tick, velocity)
        let mut active_notes: HashMap<(u8, u8), (u32, u8)> = HashMap::new();
        let mut notes: Vec<Note> = Vec::new();

        for event in track {
            current_tick += event.delta.as_int() as u64;
            let current_scaled_tick = (current_tick as f64 * scale).round() as u32;

            match event.kind {
                TrackEventKind::Meta(MetaMessage::TrackName(name_bytes)) => {
                    if let Ok(name_str) = std::str::from_utf8(name_bytes) {
                        if !name_str.trim().is_empty() {
                            track_name = name_str.trim().to_string();
                        }
                    }
                }
                TrackEventKind::Midi { channel: ch, message } => {
                    let ch_u8 = ch.as_int();
                    channel = ch_u8;
                    match message {
                        MidiMessage::ProgramChange { program: prog } => {
                            program = prog.as_int();
                        }
                        MidiMessage::NoteOn { key, vel } => {
                            let pitch = key.as_int();
                            let velocity = vel.as_int();
                            let key_pair = (ch_u8, pitch);

                            if velocity > 0 {
                                // 前の同一ノートが終了していなければ完了扱いにする
                                if let Some((start_tick, prev_vel)) = active_notes.remove(&key_pair) {
                                    let duration = current_scaled_tick.saturating_sub(start_tick).max(1);
                                    notes.push(Note {
                                        id: note_id_counter,
                                        start_tick,
                                        duration_tick: duration,
                                        pitch,
                                        velocity: prev_vel,
                                    });
                                    note_id_counter += 1;
                                }
                                active_notes.insert(key_pair, (current_scaled_tick, velocity));
                            } else {
                                // velocity 0 は NoteOff と等価
                                if let Some((start_tick, prev_vel)) = active_notes.remove(&key_pair) {
                                    let duration = current_scaled_tick.saturating_sub(start_tick).max(1);
                                    notes.push(Note {
                                        id: note_id_counter,
                                        start_tick,
                                        duration_tick: duration,
                                        pitch,
                                        velocity: prev_vel,
                                    });
                                    note_id_counter += 1;
                                    max_tick = max_tick.max(start_tick + duration);
                                }
                            }
                        }
                        MidiMessage::NoteOff { key, .. } => {
                            let pitch = key.as_int();
                            let key_pair = (ch_u8, pitch);
                            if let Some((start_tick, prev_vel)) = active_notes.remove(&key_pair) {
                                let duration = current_scaled_tick.saturating_sub(start_tick).max(1);
                                notes.push(Note {
                                    id: note_id_counter,
                                    start_tick,
                                    duration_tick: duration,
                                    pitch,
                                    velocity: prev_vel,
                                });
                                note_id_counter += 1;
                                max_tick = max_tick.max(start_tick + duration);
                            }
                        }
                        _ => {}
                    }
                }
                _ => {}
            }
        }

        // 終了していないノートの後始末
        for ((_, pitch), (start_tick, vel)) in active_notes {
            let duration = (PPQ / 4).max(1); // デフォルト16分音符長
            notes.push(Note {
                id: note_id_counter,
                start_tick,
                duration_tick: duration,
                pitch,
                velocity: vel,
            });
            note_id_counter += 1;
            max_tick = max_tick.max(start_tick + duration);
        }

        if !notes.is_empty() {
            notes.sort_by_key(|n| n.start_tick);
            if track_name.is_empty() {
                track_name = format!("Track {}", t_idx + 1);
            }
            parsed_tracks.push(Track {
                id: (t_idx + 1) as u32,
                name: track_name,
                output: Output::Gs,
                channel,
                program,
                volume: 100,
                mute: false,
                notes,
            });
        }
    }

    let ticks_per_bar = PPQ * BEATS_PER_BAR;
    let bars = ((max_tick + ticks_per_bar - 1) / ticks_per_bar).max(4);

    Ok(Project {
        bpm,
        bars,
        tracks: parsed_tracks,
    })
}

pub fn export_midi(project: &Project) -> Result<Vec<u8>, String> {
    let header = Header {
        format: Format::Parallel,
        timing: Timing::Metrical(midly::num::u15::from((PPQ as u16).min(0x7FFF))),
    };

    let mut smf = Smf::new(header);

    // Track 0: テンポ & メタトラック
    let mut tempo_track = Vec::new();
    let tempo_us = (60_000_000.0 / project.bpm.max(20.0)).round() as u32;
    tempo_track.push(TrackEvent {
        delta: 0.into(),
        kind: TrackEventKind::Meta(MetaMessage::Tempo(midly::num::u24::from(tempo_us))),
    });
    tempo_track.push(TrackEvent {
        delta: 0.into(),
        kind: TrackEventKind::Meta(MetaMessage::EndOfTrack),
    });
    smf.tracks.push(tempo_track);

    // 各トラック
    for track in &project.tracks {
        let mut track_events = Vec::new();

        // トラック名
        track_events.push((
            0u32,
            TrackEventKind::Meta(MetaMessage::TrackName(track.name.as_bytes())),
        ));

        // Program Change (channel 0-15)
        let ch = midly::num::u4::from(track.channel.min(15));
        track_events.push((
            0u32,
            TrackEventKind::Midi {
                channel: ch,
                message: MidiMessage::ProgramChange {
                    program: midly::num::u7::from(track.program.min(127)),
                },
            },
        ));

        for n in &track.notes {
            let vel = ((n.velocity as u32 * track.volume as u32) / 100).clamp(1, 127) as u8;
            track_events.push((
                n.start_tick,
                TrackEventKind::Midi {
                    channel: ch,
                    message: MidiMessage::NoteOn {
                        key: midly::num::u7::from(n.pitch.min(127)),
                        vel: midly::num::u7::from(vel),
                    },
                },
            ));
            track_events.push((
                n.start_tick + n.duration_tick,
                TrackEventKind::Midi {
                    channel: ch,
                    message: MidiMessage::NoteOff {
                        key: midly::num::u7::from(n.pitch.min(127)),
                        vel: midly::num::u7::from(0),
                    },
                },
            ));
        }

        // 時刻順でソート
        track_events.sort_by(|a, b| {
            a.0.cmp(&b.0).then_with(|| match (&a.1, &b.1) {
                (TrackEventKind::Midi { message: MidiMessage::NoteOff { .. }, .. }, _) => std::cmp::Ordering::Less,
                (_, TrackEventKind::Midi { message: MidiMessage::NoteOff { .. }, .. }) => std::cmp::Ordering::Greater,
                _ => std::cmp::Ordering::Equal,
            })
        });

        // デルタtickに変換
        let mut smf_track = Vec::new();
        let mut last_tick = 0u32;
        for (tick, kind) in track_events {
            let delta = tick.saturating_sub(last_tick);
            last_tick = tick;
            smf_track.push(TrackEvent {
                delta: midly::num::u28::from(delta),
                kind,
            });
        }
        smf_track.push(TrackEvent {
            delta: 0.into(),
            kind: TrackEventKind::Meta(MetaMessage::EndOfTrack),
        });
        smf.tracks.push(smf_track);
    }

    let mut buffer = Vec::new();
    smf.write(&mut buffer)
        .map_err(|e| format!("MIDI write error: {e}"))?;
    Ok(buffer)
}
