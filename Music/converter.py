import customtkinter as ctk
import yt_dlp
import os
import subprocess
import threading
import re

# --- GITHUB CONFIG ---
GITHUB_REPO_URL = "https://raw.githubusercontent.com/BacofyNetwork/Bacofy/main/Music/"
FFMPEG_PATH = r"C:\ffmpeg\bin\ffmpeg.exe"
FFMPEG_DIR = r"C:\ffmpeg\bin"

ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")

class BacofyApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("BACOFY ULTIMATE CONVERTER")
        self.geometry("600x650")

        ctk.CTkLabel(self, text="BACOFY CONVERTER", font=("Roboto", 24, "bold")).pack(pady=10)

        # Das neue Tab-System!
        self.tabs = ctk.CTkTabview(self, width=550, height=250)
        self.tabs.pack(pady=10)
        
        # --- TAB 1: EINZELNER SONG ---
        tab_single = self.tabs.add("Einzelner Song")
        self.s_url = ctk.CTkEntry(tab_single, placeholder_text="YouTube URL...", width=450)
        self.s_url.pack(pady=10)
        self.s_pl = ctk.CTkEntry(tab_single, placeholder_text="In welche Playlist? (z.B. Kpop, Chill)", width=450)
        self.s_pl.pack(pady=10)
        self.s_name = ctk.CTkEntry(tab_single, placeholder_text="Eigener Name (z.B. PSY - Daddy)", width=450)
        self.s_name.pack(pady=10)
        self.btn_s = ctk.CTkButton(tab_single, text="SINGLE DOWNLOAD & PUSH", command=lambda: self.start_process("single"))
        self.btn_s.pack(pady=10)

        # --- TAB 2: PLAYLIST ---
        tab_multi = self.tabs.add("Ganze Playlist")
        self.m_url = ctk.CTkEntry(tab_multi, placeholder_text="YouTube Playlist URL...", width=450)
        self.m_url.pack(pady=20)
        self.m_pl = ctk.CTkEntry(tab_multi, placeholder_text="In welche Playlist? (z.B. Kpop, Chill)", width=450)
        self.m_pl.pack(pady=20)
        self.btn_m = ctk.CTkButton(tab_multi, text="PLAYLIST DOWNLOAD & PUSH", command=lambda: self.start_process("multi"))
        self.btn_m.pack(pady=20)

        # --- STATUS FENSTER ---
        self.status_box = ctk.CTkTextbox(self, width=550, height=200, font=("Consolas", 12))
        self.status_box.pack(pady=10)

    def log(self, text):
        self.status_box.insert("end", f"> {text}\n"); self.status_box.see("end")

    def start_process(self, mode):
        self.btn_s.configure(state="disabled")
        self.btn_m.configure(state="disabled")
        threading.Thread(target=self.process, args=(mode,)).start()

    def process(self, mode):
        music_dir = "Music"
        
        # Felder auslesen je nach aktivem Tab
        if mode == "single":
            url = self.s_url.get().strip()
            pl_name = self.s_pl.get().strip() or "Unsortiert"
            custom_name = self.s_name.get().strip()
            if not url or not custom_name:
                self.log("FEHLER: Bitte URL und eigenen Namen ausfüllen!")
                self.btn_s.configure(state="normal"); self.btn_m.configure(state="normal")
                return
        else:
            url = self.m_url.get().strip()
            pl_name = self.m_pl.get().strip() or "Unsortiert"
            custom_name = None
            if not url:
                self.log("FEHLER: Bitte Playlist-URL ausfüllen!")
                self.btn_s.configure(state="normal"); self.btn_m.configure(state="normal")
                return

        try:
            self.log("Synchronisiere GitHub...")
            subprocess.run(["git", "pull", "origin", "main"], check=True)
            if not os.path.exists(music_dir): os.makedirs(music_dir)

            self.log("Analysiere YouTube-Link...")
            with yt_dlp.YoutubeDL({'extract_flat': True, 'quiet': True}) as ydl:
                info = ydl.extract_info(url, download=False)
                if mode == "single":
                    entries = [info] # Zwinge ihn auf 1 Song
                    self.log("Modus: Einzelner Song")
                else:
                    entries = info.get('entries', [info])
                    self.log(f"Modus: Playlist ({len(list(entries))} Songs gefunden)")

            # Info-Daten zurücksetzen für den Download Loop
            if mode != "single":
                entries = info.get('entries', [info])

            count = 0
            for entry in entries:
                if not entry: continue
                
                # Den Anzeige-Namen für Minecraft bestimmen
                if mode == "single":
                    display_name = custom_name
                    video_url = url
                else:
                    display_name = entry.get('title', 'Unbekannter Song')
                    video_url = entry.get('url') or f"https://www.youtube.com/watch?v={entry.get('id')}"
                
                safe_file_name = re.sub(r'[^a-zA-Z0-9]', '', display_name)
                if not safe_file_name: safe_file_name = f"Song_Auto_{count}"
                output_file = os.path.join(music_dir, f"{safe_file_name}.raw")

                self.log(f"Lade: {display_name}...")
                ydl_opts = {'format': 'bestaudio/best', 'outtmpl': 'temp.%(ext)s', 'ffmpeg_location': FFMPEG_DIR, 'postprocessors': [{'key': 'FFmpegExtractAudio', 'preferredcodec': 'wav'}], 'quiet': True}
                with yt_dlp.YoutubeDL(ydl_opts) as ydl: ydl.download([video_url])

                self.log("Konvertiere zu HQ RAW (Anti-Kratz)...")
                subprocess.run([FFMPEG_PATH, '-y', '-i', 'temp.wav', '-af', 'volume=-5dB,aresample=48000', '-ac', '1', '-ar', '48000', '-f', 's8', '-acodec', 'pcm_s8', output_file], check=True)

                # Die spezifische Playlist-Datei (z.B. Kpop.txt) updaten
                pl_file_path = os.path.join(music_dir, f"{pl_name}.txt")
                entry_line = f"{GITHUB_REPO_URL}{safe_file_name}.raw, {display_name}\n"
                song_exists = False
                
                if os.path.exists(pl_file_path):
                    with open(pl_file_path, "r", encoding="utf-8") as f:
                        if entry_line in f.readlines(): song_exists = True
                        
                if not song_exists:
                    with open(pl_file_path, "a", encoding="utf-8") as f:
                        f.write(entry_line)
                
                # Master-Datei updaten (Damit die Playlist Ingame angezeigt wird)
                master_path = os.path.join(music_dir, "master.txt")
                playlists = []
                if os.path.exists(master_path):
                    with open(master_path, "r", encoding="utf-8") as f: playlists = [l.strip() for l in f.readlines()]
                if pl_name not in playlists:
                    with open(master_path, "a", encoding="utf-8") as f: f.write(f"{pl_name}\n")

                if os.path.exists('temp.wav'): os.remove('temp.wav')
                count += 1

            self.log(f"Pushe {count} Datei(en) zu GitHub...")
            subprocess.run(["git", "add", "."], check=True)
            subprocess.run(["git", "commit", "-m", f"Added {count} song(s) to {pl_name}"], check=True)
            subprocess.run(["git", "push", "origin", "main"], check=True)
            self.log("ERFOLGREICH! Alles ist online. 🥓")
            
            # Felder nach Erfolg leeren
            if mode == "single":
                self.s_url.delete(0, 'end')
                self.s_name.delete(0, 'end')
            else:
                self.m_url.delete(0, 'end')

        except Exception as e: 
            self.log(f"FEHLER: {str(e)}")
        finally: 
            self.btn_s.configure(state="normal")
            self.btn_m.configure(state="normal")

if __name__ == "__main__": BacofyApp().mainloop()