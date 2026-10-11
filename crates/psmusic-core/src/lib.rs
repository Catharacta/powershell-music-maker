pub mod generator;
pub mod midi;
pub mod model;
pub mod player;
pub mod test_env;
pub mod timeline;

pub use generator::{generate_script, GeneratorOptions};
pub use midi::{export_midi, parse_midi};
pub use model::{
    note_name, note_to_freq, parse_project_json, tick_to_ms, Note, Output, Project, ProjectFile,
    Track, BEATS_PER_BAR, PPQ,
};
pub use player::Player;
pub use test_env::{list_midi_devices, test_beep, test_gs, TestResult};
pub use timeline::{build_timeline, BeepOverlap, EventKind, TLEvent, Timeline, TimelineOptions};

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tick_and_freq_calc() {
        assert_eq!(tick_to_ms(0, 120.0), 0.0);
        assert_eq!(tick_to_ms(PPQ, 120.0), 500.0);
        assert_eq!(note_to_freq(69), 440);
        assert_eq!(note_name(69), "A4");
        assert_eq!(note_name(60), "C4");
    }

    #[test]
    fn test_timeline_and_generator() {
        let mut project = Project::default();
        project.bpm = 120.0;
        project.tracks.push(Track {
            id: 1,
            name: "Melody".to_string(),
            output: Output::Beep,
            channel: 0,
            program: 0,
            volume: 100,
            mute: false,
            notes: vec![
                Note {
                    id: 1,
                    start_tick: 0,
                    duration_tick: 480,
                    pitch: 69,
                    velocity: 100,
                },
                Note {
                    id: 2,
                    start_tick: 480,
                    duration_tick: 480,
                    pitch: 71,
                    velocity: 100,
                },
            ],
        });

        let tl = build_timeline(&project, TimelineOptions::default());
        assert_eq!(tl.events.len(), 2);
        assert_eq!(tl.has_beep, true);
        assert_eq!(tl.has_gs, false);
        assert_eq!(tl.end_ms, 1000.0);

        let script = generate_script(&project, &tl, GeneratorOptions::default());
        assert!(script.contains("PsMusic"));
        assert!(script.contains("B 0 440 500"));
        assert!(script.contains("B 0 494 500"));
    }

    #[test]
    fn test_midi_roundtrip() {
        let mut project = Project::default();
        project.bpm = 140.0;
        project.tracks.push(Track {
            id: 1,
            name: "Piano".to_string(),
            output: Output::Gs,
            channel: 0,
            program: 0,
            volume: 100,
            mute: false,
            notes: vec![
                Note {
                    id: 1,
                    start_tick: 0,
                    duration_tick: 240,
                    pitch: 60,
                    velocity: 100,
                },
                Note {
                    id: 2,
                    start_tick: 240,
                    duration_tick: 240,
                    pitch: 64,
                    velocity: 90,
                },
            ],
        });

        let bytes = export_midi(&project).expect("Failed to export MIDI");
        let parsed = parse_midi(&bytes).expect("Failed to parse MIDI");
        assert_eq!(parsed.bpm, 140.0);
        assert_eq!(parsed.tracks.len(), 1);
        assert_eq!(parsed.tracks[0].notes.len(), 2);
        assert_eq!(parsed.tracks[0].notes[0].pitch, 60);
        assert_eq!(parsed.tracks[0].notes[1].pitch, 64);
    }
}
