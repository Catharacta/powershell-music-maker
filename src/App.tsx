import { useState } from "react";
import { save } from "@tauri-apps/plugin-dialog";
import { writeTextFile } from "@tauri-apps/plugin-fs";
import { Note } from "./types";
import { PianoRoll } from "./PianoRoll";
import { generatePowerShellScript } from "./exportScript";
import "./App.css";

function App() {
  const [notes, setNotes] = useState<Note[]>([]);
  const [bpm, setBpm] = useState<number>(120);
  const [activeSynthType, setActiveSynthType] = useState<'beep' | 'synth'>('synth');

  const handleAddNote = (pitch: number, beat: number) => {
    setNotes([...notes, { pitch, start_beat: beat, duration_beat: 1, synth_type: activeSynthType }]);
  };

  const handleRemoveNote = (pitch: number, beat: number) => {
    setNotes(notes.filter(n => !(n.pitch === pitch && n.start_beat === beat)));
  };

  const handleExport = async () => {
    try {
      const scriptContent = generatePowerShellScript(notes, bpm);
      const filePath = await save({
        filters: [{
          name: 'PowerShell',
          extensions: ['ps1']
        }]
      });

      if (filePath) {
        await writeTextFile(filePath, scriptContent);
        alert('Script exported successfully!');
      }
    } catch (error) {
      console.error('Error exporting script:', error);
      alert('Failed to export script.');
    }
  };

  return (
    <main className="container" style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '20px' }}>
      <h1>PowerShell Music Generator</h1>

      <div style={{ display: 'flex', gap: '20px', alignItems: 'center' }}>
        <div>
          <label htmlFor="bpm-input">BPM: </label>
          <input
            id="bpm-input"
            type="number"
            value={bpm}
            onChange={(e) => setBpm(Number(e.target.value))}
            min="30"
            max="300"
            style={{ width: '60px' }}
          />
        </div>

        <div>
          <label>Synth Type: </label>
          <select
            value={activeSynthType}
            onChange={(e) => setActiveSynthType(e.target.value as 'beep' | 'synth')}
          >
            <option value="beep">Beep</option>
            <option value="synth">MS GS Wavetable Synth</option>
          </select>
        </div>

        <button onClick={handleExport} style={{ backgroundColor: '#2196f3', color: 'white', padding: '8px 16px', border: 'none', borderRadius: '4px', cursor: 'pointer' }}>
          Export PowerShell Script
        </button>
      </div>

      <PianoRoll
        notes={notes}
        onAddNote={handleAddNote}
        onRemoveNote={handleRemoveNote}
      />
    </main>
  );
}

export default App;
