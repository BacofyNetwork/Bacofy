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
        self.title("BACOFY RAW (Anti-Bass-Kratzen)")
        self.geometry("550x550")

        ctk.CTkLabel(self, text="BACOFY CONVERTER", font=("Roboto", 24, "bold")).pack(pady=20)
        
        self.url_entry = ctk.CTkEntry(self, placeholder_text="YouTube URL...", width=450)
        self.url_entry.pack(pady=10)
        
        self.name_entry = ctk.CTkEntry(self, placeholder_text="Song Name (Anzeige in Minecraft)", width=450)
        self.name_entry.pack(pady=10)

        self.btn = ctk.CTkButton(self, text="RAW KONVERTIEREN & PUSH", command=self.start_process)
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
        d_name = self.name_entry.get().strip()
        
        if not url or not d_name:
            self.log("FEHLER: Bitte URL und Name ausfüllen!")
            self.btn.configure(state="normal")
            return

        music_dir = "Music" 

        try:
            self.log("Synchronisiere GitHub...")
            subprocess.run(["git", "pull", "origin", "main"], check=True)

            safe_name = re.sub(r'[^a-zA-Z0-9]', '', d_name)
            output_file = os.path.join(music_dir, f"{safe_name}.raw")
            
            if not os.path.exists(music_dir): 
                os.makedirs(music_dir)

            self.log("Lade von YouTube...")
            ydl_opts = {
                'format': 'bestaudio/best', 
                'outtmpl': 'temp.%(ext)s', 
                'ffmpeg_location': FFMPEG_DIR, 
                'postprocessors': [{'key': 'FFmpegExtractAudio', 'preferredcodec': 'wav'}]
            }
            with yt_dlp.YoutubeDL(ydl_opts) as ydl: 
                ydl.download([url])
            
            # --- DER MAGISCHE FILTER ---
            # volume=-5dB gibt dem Bass den nötigen Headroom!
            self.log("Konvertiere zu RAW (Anti-Kratz-Filter aktiv)...")
            subprocess.run([
                FFMPEG_PATH, '-y', '-i', 'temp.wav',
                '-af', 'volume=-5dB,aresample=48000:resample_cutoff=0.99:dither_method=triangular',
                '-ac', '1', '-ar', '48000', '-f', 's8', '-acodec', 'pcm_s8',
                output_file
            ], check=True)

            self.log("Update songlist.txt...")
            playlist_path = os.path.join(music_dir, "songlist.txt")
            
            # Wir prüfen, ob das Lied schon in der Liste steht, um doppelte Einträge zu vermeiden
            song_entry = f"{BASE_URL}{safe_name}.raw, {d_name}\n"
            song_exists = False
            if os.path.exists(playlist_path):
                with open(playlist_path, "r", encoding="utf-8") as f:
                    if song_entry in f.readlines():
                        song_exists = True
            
            if not song_exists:
                with open(playlist_path, "a", encoding="utf-8") as f: 
                    f.write(song_entry)

            self.log("Pushe zu GitHub...")
            subprocess.run(["git", "add", "."], check=True)
            subprocess.run(["git", "commit", "-m", f"Add Song: {d_name}"], check=True)
            subprocess.run(["git", "push", "origin", "main"], check=True)

            if os.path.exists('temp.wav'): os.remove('temp.wav')
            self.log(f"ERFOLGREICH! '{d_name}' ist online. 🥓")
            
            self.url_entry.delete(0, 'end')
            self.name_entry.delete(0, 'end')
            
        except Exception as e: 
            self.log(f"FEHLER: {str(e)}")
        finally: 
            self.btn.configure(state="normal")

if __name__ == "__main__":
    BacofyApp().mainloop()