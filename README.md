📚 Audio Book Compiler Script
This Bash script automates the process of merging multiple .m4a & .flac audio files into a single .m4b audiobook file with embedded chapter metadata.

🔧 Features
Automatically detects and sorts audio files by CD and track number using ffprobe

Generates chapter metadata based on track titles and durations

Concatenates all audio files into one .m4a stream

Converts the final output to .m4b format with AAC encoding and stereo audio

Cleans up temporary files after processing

📁 Requirements
ffmpeg and ffprobe installed

Audio files located in a folder named Audio Books

🚀 Usage
Simply run the script in a directory containing the Audio Books folder. The output will be a chapterized .m4b audiobook named after the album title.
