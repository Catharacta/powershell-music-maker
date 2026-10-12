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

        let script = generate_script(
            &project,
            &tl,
            GeneratorOptions {
                visualizer: true,
                title: Some("テスト曲".to_string()),
                artist: Some("作曲者".to_string()),
            },
        );
        assert!(script.contains("PsMusic"));
        // 型キャッシュ衝突を防ぐため、Beepのみでも PsMusic クラスには winmm.dll 定義が含まれるが、演奏部では Open() は呼ばれない
        assert!(script.contains("winmm.dll"));
        assert!(!script.contains("[PsMusic]::Open()"));
        assert!(script.contains("[Console]::Beep(37, 1)"));
        // 日本語が '?' にならずそのまま保持される
        assert!(script.contains("テスト曲"));
        assert!(script.contains("作曲者"));
        assert!(script.contains("Melody"));
        // ループ再生用構文
        assert!(script.contains("do {"));
        assert!(script.contains("while ([PsMusic]::ShouldLoop())"));
        assert!(script.contains("B 0 440 480"));
        assert!(script.contains("B 0 494 500"));

        // GSトラックを含む場合は winmm.dll と [PsMusic]::Open() が入る
        project.tracks.push(Track {
            id: 2,
            name: "和音トラック".to_string(),
            output: Output::Gs,
            channel: 1,
            program: 48,
            volume: 100,
            mute: false,
            notes: vec![Note {
                id: 3,
                start_tick: 0,
                duration_tick: 480,
                pitch: 60,
                velocity: 100,
            }],
        });
        let tl_gs = build_timeline(&project, TimelineOptions::default());
        let script_gs = generate_script(&project, &tl_gs, GeneratorOptions::default());
        assert!(script_gs.contains("winmm.dll"));
        assert!(script_gs.contains("[PsMusic]::Open()"));
        assert!(script_gs.contains("和音トラック"));

        // GSトラックにノートが空（0個）の場合でも、GSトラックが存在すれば winmm.dll が入る
        let mut empty_gs_project = Project::default();
        empty_gs_project.tracks.push(Track {
            id: 1,
            name: "空GS".to_string(),
            output: Output::Gs,
            channel: 0,
            program: 0,
            volume: 100,
            mute: false,
            notes: vec![],
        });
        empty_gs_project.tracks.push(Track {
            id: 2,
            name: "Beep".to_string(),
            output: Output::Beep,
            channel: 2,
            program: 0,
            volume: 100,
            mute: false,
            notes: vec![Note {
                id: 1,
                start_tick: 0,
                duration_tick: 480,
                pitch: 60,
                velocity: 100,
            }],
        });
        let tl_empty_gs = build_timeline(&empty_gs_project, TimelineOptions::default());
        let script_empty_gs = generate_script(&empty_gs_project, &tl_empty_gs, GeneratorOptions::default());
        assert!(script_empty_gs.contains("winmm.dll"));
        assert!(script_empty_gs.contains("[PsMusic]::Open()"));
    }

    #[test]
    fn test_beep_gap_and_min_dur() {
        let mut project = Project::default();
        project.bpm = 120.0;
        project.tracks.push(Track {
            id: 1,
            name: "BeepTest".to_string(),
            output: Output::Beep,
            channel: 0,
            program: 0,
            volume: 100,
            mute: false,
            notes: vec![
                // 10msの極小ノート -> min_dur 25ms に延長されるが後ろの音とのギャップ20msも考慮
                Note {
                    id: 1,
                    start_tick: 0,
                    duration_tick: 10,
                    pitch: 60,
                    velocity: 100,
                },
                // 1000 tick のノート (約1042ms)
                Note {
                    id: 2,
                    start_tick: 500,
                    duration_tick: 1000,
                    pitch: 64,
                    velocity: 100,
                },
            ],
        });

        let tl = build_timeline(
            &project,
            TimelineOptions {
                beep_overlap: BeepOverlap::Latest,
                beep_min_gap_ms: 20,
                beep_min_dur_ms: 25,
            },
        );

        assert_eq!(tl.events.len(), 2);
        // 最初のノートは min_dur_ms=25 が保証される (500 tick ≒ 521ms なので十分な空き時間がある)
        assert_eq!(tl.events[0].dur_ms, Some(25));
        // 2番目のノートは末尾に音がないのでそのままの長さ (1000 tick ≒ 1042ms)
        assert_eq!(tl.events[1].dur_ms, Some(1042));
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
