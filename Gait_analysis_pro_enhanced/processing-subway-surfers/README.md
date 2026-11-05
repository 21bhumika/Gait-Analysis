# Subway Surfers (Processing Edition)
By *Nathan Moore*

This project represents a recreation of Subway Surfers, using 3D rendering with OpenGL, audio processing, animation, and custom obstacle models.

## Getting Started
Run `main()` method in `SSApp` class to launch the game.  Use 'A' and 'D' keys to move, 'Space' to jump.

### Requirements
This project was created on Windows using an editor other than the official Processing PDE, therefore it requires external library package files to run.  These can be found in the `csc-121-creative-project/` directory and should be included when cloning the repository.  If this does not occur, links to download these libraries will be added here soon.  Other libraries may be required to run the project on Mac or Linux systems.  The project author assumes no responsibility for files downloaded from external sites.
- Processing Core (`core.jar`)
- Processing Sound (`sound.jar`)
- JSyn: Audio Synthesis API for Java (`jsyn-20171016.jar`) - https://www.softsynth.com/jsyn/developers/download.php
- JavaMP3 (`javamp3-1.0.4.jar`)
- JogAmp (`jogamp-fat.jar`) (used for 3D rendering, may not be necessary if running in PDE)

If you plan to run the project by importing it into the Processing PDE, omit the Processing Core `.jar` file, install the Sound library from the built-in Library Manager, and omit the Processing Sound, JSyn, and JavaMP3 `.jar` files, as these are automatically imported when installing the library.

>[!NOTE]
>When launching the game on Windows, automatic window resizing may occur.  This is external to Processing and occurs when using 3D rendering. No known fixes have been found or are planned for this project.

*Created for Berry College CSC 121. Not affiliated with Subway Surfers or Sybo Games ApS.*
