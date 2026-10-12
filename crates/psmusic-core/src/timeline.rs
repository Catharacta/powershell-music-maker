use crate::model::{note_to_freq, tick_to_ms, Output, Project};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum EventKind {
    GsProg,
    GsOff,
    GsOn,
    Beep,
}

impl EventKind {
    pub fn as_str(&self) -> &'static str {
        match self {
            EventKind::GsProg => "gs_prog",
            EventKind::GsOff => "gs_off",
            EventKind::GsOn => "gs_on",
            EventKind::Beep => "beep",
        }
    }
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct TLEvent {
    pub t_ms: f64,
    /// "gs_prog" | "gs_on" | "gs_off" | "beep"
    pub kind: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub track_index: Option<usize>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ch: Option<u8>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pitch: Option<u8>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub vel: Option<u8>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub program: Option<u8>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub freq: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub dur_ms: Option<u32>,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Timeline {
    pub events: Vec<TLEvent>,
    /// Beepは同時1音のため、重なりで切り詰め/破棄したノート数
    pub beep_conflicts: usize,
    /// 全体の終了時刻(ms)
    pub end_ms: f64,
    pub has_gs: bool,
    pub has_beep: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BeepOverlap {
    Latest,
    Ignore,
}

impl Default for BeepOverlap {
    fn default() -> Self {
        BeepOverlap::Latest
    }
}

#[derive(Clone, Copy, Debug)]
pub struct TimelineOptions {
    pub beep_overlap: BeepOverlap,
    pub beep_min_gap_ms: u32,
    pub beep_min_dur_ms: u32,
}

impl Default for TimelineOptions {
    fn default() -> Self {
        Self {
            beep_overlap: BeepOverlap::Latest,
            beep_min_gap_ms: 20,
            beep_min_dur_ms: 25,
        }
    }
}

struct RawBeepNote {
    start_tick: u32,
    duration_tick: u32,
    pitch: u8,
    track_index: usize,
}

pub fn build_timeline(p: &Project, options: TimelineOptions) -> Timeline {
    let mut events = Vec::new();
    let mut has_gs = false;
    let mut has_beep = false;
    let mut beep_conflicts = 0;
    let min_gap_ms = (options.beep_min_gap_ms as f64).max(15.0);
    let min_dur_ms = (options.beep_min_dur_ms as f64).max(1.0);

    // GS: トラック単位で Program Change + NoteOn/Off
    for (t_idx, t) in p.tracks.iter().enumerate() {
        if t.mute || t.output != Output::Gs || t.notes.is_empty() {
            continue;
        }
        has_gs = true;
        events.push(TLEvent {
            t_ms: 0.0,
            kind: EventKind::GsProg.as_str().to_string(),
            track_index: Some(t_idx),
            ch: Some(t.channel),
            pitch: None,
            vel: None,
            program: Some(t.program),
            freq: None,
            dur_ms: None,
        });

        for n in &t.notes {
            let vel = ((n.velocity as u32 * t.volume as u32) / 100).clamp(1, 127) as u8;
            events.push(TLEvent {
                t_ms: tick_to_ms(n.start_tick, p.bpm).round(),
                kind: EventKind::GsOn.as_str().to_string(),
                track_index: Some(t_idx),
                ch: Some(t.channel),
                pitch: Some(n.pitch),
                vel: Some(vel),
                program: None,
                freq: None,
                dur_ms: None,
            });
            events.push(TLEvent {
                t_ms: tick_to_ms(n.start_tick + n.duration_tick, p.bpm).round(),
                kind: EventKind::GsOff.as_str().to_string(),
                track_index: Some(t_idx),
                ch: Some(t.channel),
                pitch: Some(n.pitch),
                vel: None,
                program: None,
                freq: None,
                dur_ms: None,
            });
        }
    }

    // Beep: 全Beepトラックを1本にまとめ、後から来た音を優先して前の音を切り詰める(または先優先)
    let mut beep_notes = Vec::new();
    for (t_idx, t) in p.tracks.iter().enumerate() {
        if t.mute || t.output != Output::Beep {
            continue;
        }
        for n in &t.notes {
            beep_notes.push(RawBeepNote {
                start_tick: n.start_tick,
                duration_tick: n.duration_tick,
                pitch: n.pitch,
                track_index: t_idx,
            });
        }
    }

    // ソート: start_tick 昇順、同一時刻なら pitch 降順
    beep_notes.sort_by(|a, b| {
        a.start_tick
            .cmp(&b.start_tick)
            .then_with(|| b.pitch.cmp(&a.pitch))
    });

    match options.beep_overlap {
        BeepOverlap::Ignore => {
            let mut current_end_tick = 0;
            let mut kept = Vec::new();
            for item in beep_notes {
                if item.start_tick < current_end_tick {
                    beep_conflicts += 1;
                    continue;
                }
                current_end_tick = item.start_tick + item.duration_tick;
                kept.push(item);
            }
            let len = kept.len();
            for i in 0..len {
                has_beep = true;
                let item = &kept[i];
                let s = tick_to_ms(item.start_tick, p.bpm).round();
                let mut e = tick_to_ms(item.start_tick + item.duration_tick, p.bpm).round();
                let dur = if i + 1 < len {
                    let next = &kept[i + 1];
                    let next_s = tick_to_ms(next.start_tick, p.bpm).round();
                    if next_s - e < min_gap_ms {
                        e = next_s - min_gap_ms;
                    }
                    let avail = (next_s - s - min_gap_ms).max(1.0);
                    (e - s).max(min_dur_ms).min(avail).max(1.0)
                } else {
                    (e - s).max(min_dur_ms).max(1.0)
                };
                events.push(TLEvent {
                    t_ms: s,
                    kind: EventKind::Beep.as_str().to_string(),
                    track_index: Some(item.track_index),
                    ch: None,
                    pitch: Some(item.pitch),
                    vel: None,
                    program: None,
                    freq: Some(note_to_freq(item.pitch)),
                    dur_ms: Some(dur as u32),
                });
            }
        }
        BeepOverlap::Latest => {
            let mut kept = Vec::new();
            for item in beep_notes {
                if let Some(last) = kept.last() {
                    if (last as &RawBeepNote).start_tick == item.start_tick {
                        beep_conflicts += 1;
                        continue;
                    }
                }
                kept.push(item);
            }

            let len = kept.len();
            for i in 0..len {
                has_beep = true;
                let item = &kept[i];
                let mut end_tick = item.start_tick + item.duration_tick;
                let next_opt = if i + 1 < len { Some(&kept[i + 1]) } else { None };
                if let Some(next) = next_opt {
                    if next.start_tick < end_tick {
                        end_tick = next.start_tick;
                        beep_conflicts += 1;
                    }
                }
                let s = tick_to_ms(item.start_tick, p.bpm).round();
                let mut raw_e = tick_to_ms(end_tick, p.bpm).round();
                let dur = if let Some(next) = next_opt {
                    let next_s = tick_to_ms(next.start_tick, p.bpm).round();
                    if next_s - raw_e < min_gap_ms {
                        raw_e = next_s - min_gap_ms;
                    }
                    let avail = (next_s - s - min_gap_ms).max(1.0);
                    (raw_e - s).max(min_dur_ms).min(avail).max(1.0)
                } else {
                    (raw_e - s).max(min_dur_ms).max(1.0)
                };
                events.push(TLEvent {
                    t_ms: s,
                    kind: EventKind::Beep.as_str().to_string(),
                    track_index: Some(item.track_index),
                    ch: None,
                    pitch: Some(item.pitch),
                    vel: None,
                    program: None,
                    freq: Some(note_to_freq(item.pitch)),
                    dur_ms: Some(dur as u32),
                });
            }
        }
    }

    fn kind_rank(k: &str) -> u8 {
        match k {
            "gs_prog" => 0,
            "gs_off" => 1,
            "gs_on" => 2,
            "beep" => 2,
            _ => 3,
        }
    }

    events.sort_by(|a, b| {
        a.t_ms
            .partial_cmp(&b.t_ms)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| kind_rank(&a.kind).cmp(&kind_rank(&b.kind)))
    });

    let end_ms = events
        .iter()
        .fold(0.0_f64, |m, e| m.max(e.t_ms + e.dur_ms.unwrap_or(0) as f64));

    Timeline {
        events,
        beep_conflicts,
        end_ms,
        has_gs,
        has_beep,
    }
}
