import customtkinter as ctk
import yt_dlp
import os
import subprocess
import threading
import re

# --- GITHUB CONFIG ---
BASE_URL = "https://raw.githubusercontent.com/BacofyNetwork/Bacofy/main/Music/"
FFMPEG_PATH = r"C:\ffmpeg\bin\ffmpeg.exe"
FFMPEG_DIR = r"C:\ffmpeg\bin"

ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")

class BacofyApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("BACOFY AUTO-RAW (Playlists & Singles)")
        self.geometry("550x500") # Kleiner, da wir weniger Felder brauchen!

        ctk.CTkLabel(self, text="BACOFY AUTO-CONVERTER", font=("Roboto", 24, "bold")).pack(pady=20)
        
        # Nur noch EIN Feld!
        self.url_entry = ctk.CTkEntry(self, placeholder_text="YouTube URL (Video oder Playlist)...", width=450)
        self.url_entry.pack(pady=10)

        self.btn = ctk.CTkButton(self, text="DOWNLOAD & PUSH", command=self.start_process)
        self.btn.pack(pady=20)

        self.status_box = ctk.CTkTextbox(self, width=450, height=200, font=("Consolas", 12))
        self.status_box.pack(pady=10)

    def log(self, text):
        self.status_box.insert("end", f"> {text}\n"); self.status_box.see("end")

    def start_process(self):
        self.btn.configure(state="disabled")
        threading.Thread(target=self.process).start()

    def process(self):
        url = self.url_entry.get().strip()
        if not url:
            self.log("FEHLER: Bitte URL ausfüllen!")
            self.btn.configure(state="normal")
            return

        music_dir = "Music" 

        try:
            self.log("Synchronisiere GitHub...")
            subprocess.run(["git", "pull", "origin", "main"], check=True)

            if not os.path.exists(music_dir): 
                os.makedirs(music_dir)

            # 1. Infos abrufen (Ist es ein Video oder eine Playlist?)
            self.log("Analysiere YouTube-Link...")
            ydl_opts_info = {'extract_flat': True, 'quiet': True}
            
            with yt_dlp.YoutubeDL(ydl_opts_info) as ydl:
                info = ydl.extract_info(url, download=False)
                if 'entries' in info:
                    entries = list(info['entries']) # Es ist eine Playlist!
                    self.log(f"PLAYLIST ERKANNT: {len(entries)} Songs gefunden!")
                else:
                    entries = [info] # Es ist ein einzelnes Video
                    self.log("EINZELNES VIDEO ERKANNT.")

            playlist_path = os.path.join(music_dir, "songlist.txt")
            
            # Download-Einstellungen
            ydl_opts = {
                'format': 'bestaudio/best', 
                'outtmpl': 'temp.%(ext)s', 
                'ffmpeg_location': FFMPEG_DIR, 
                'postprocessors': [{'key': 'FFmpegExtractAudio', 'preferredcodec': 'wav'}],
                'quiet': True # Macht die Konsole sauberer
            }

            added_count = 0

            # 2. Schleife für alle gefundenen Lieder
            for entry in entries:
                if not entry: continue
                
                # YouTube Titel als Namen nutzen
                title = entry.get('title', 'Unbekannter Song')
                video_id = entry.get('id')
                video_url = f"https://www.youtube.com/watch?v={video_id}"

                self.log(f"Lade: {title}...")
                
                # Sonderzeichen für den Dateinamen entfernen, aber Titel behalten
                safe_name = re.sub(r'[^a-zA-Z0-9]', '', title)
                if not safe_name: safe_name = f"Song_{video_id}"
                output_file = os.path.join(music_dir, f"{safe_name}.raw")
                
                # Herunterladen
                with yt_dlp.YoutubeDL(ydl_opts) as ydl: 
                    ydl.download([video_url])
                
                # HQ RAW Konvertierung
                subprocess.run([
                    FFMPEG_PATH, '-y', '-i', 'temp.wav',
                    '-af', 'aresample=48000:resample_cutoff=0.99:dither_method=triangular,volume=-1dB',
                    '-ac', '1', '-ar', '48000', '-f', 's8', '-acodec', 'pcm_s8',
                    output_file
                ], check=True)

                # In die Liste schreiben (Titel wird mit Sonderzeichen schön in Minecraft angezeigt)
                with open(playlist_path, "a", encoding="utf-8") as f: 
                    f.write(f"{BASE_URL}{safe_name}.raw, {title}\n")

                if os.path.exists('temp.wav'): os.remove('temp.wav')
                added_count += 1

            # 3. Wenn alles fertig ist: Ein großer Push zu GitHub
            self.log(f"Pushe {added_count} Song(s) zu GitHub...")
            subprocess.run(["git", "add", "."], check=True)
            subprocess.run(["git", "commit", "-m", f"Auto-Add: {added_count} Songs(s)"], check=True)
            subprocess.run(["git", "push", "origin", "main"], check=True)

            self.log("ERFOLGREICH! Alle Songs sind online. 🥓")
            self.url_entry.delete(0, 'end') # Feld für den nächsten Link leeren
            
        except Exception as e: 
            self.log(f"FEHLER: {str(e)}")
        finally: 
            self.btn.configure(state="normal")

if __name__ == "__main__":
    BacofyApp().mainloop()