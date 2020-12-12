Please read the license file.

This plugin software development kit needs MacOS X 10.9 or more.

Once installed, you can launch Xcode and create a new project by choosing the "Lynkeos" project templates subset and the kind of plugin inside that subset.
This starts a project which links against the LynkeosCore framework and provides skeleton source code files.
To fill in the methods bodies, read the documentation by opening the index.html in the "Library/Documentation/LynkeosCoreDoc" folder in your home folder or startup disk (depending on installation choice).

Once built, the plugin shall be placed in the folder "Library/Application Support/Lynkeos/Plugins/" (in your home folder or startup disk) in order to be loaded by Lynkeos when launched.

To debug, you should add the Lynkeos application as a new executable to your Xcode project, and start the debugger with Lynkeos as the active executable. Of course, the plugin built with the debug configuration shall be placed in the plugins folder as described above.

Lynkeos plugin SDK, Copyright © 2008-2020 J-E. Lamiaud.
http://lynkeos.sourceforge.net/
