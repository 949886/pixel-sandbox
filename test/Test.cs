using Godot;
using System;
using System.Runtime.InteropServices;

public partial class Test : Label
{
    int count = 0;

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int MessageBox(IntPtr hWnd, String text, String caption, uint type);

#if DEBUG
  #if GODOT_WINDOWS
    // [DllImport("./bin/luna/Luna.cpp.dll", CharSet = CharSet.Unicode)]
    [DllImport("./bin/example/libgdexample.windows.template_debug.x86_64.dll", CharSet = CharSet.Unicode)]
  #elif GODOT_ANDROID
	[DllImport("libgdexample.android.template_debug.arm64.so", CharSet = CharSet.Unicode)]
  #endif
#else
  #if GODOT_WINDOWS
	// [DllImport("Luna.cpp.dll", CharSet = CharSet.Unicode)]
	[DllImport("libgdexample.windows.template_release.x86_64.dll", CharSet = CharSet.Unicode)]
  #elif GODOT_ANDROID
	[DllImport("libgdexample.android.template_release.arm64.so", CharSet = CharSet.Unicode)]
  #endif
#endif
    public static extern int Add(int n1, int n2);


    public override void _Ready()
    {
        this.Visible = true;
        GetNode<Label>("../GDScript Label").Visible = false;
        
        // Call the MessageBox function using platform invoke.
        var result = Add(1, 2);
        // MessageBox(new IntPtr(0), $"1 + 2 = {result}", "Result", 0);
    }

    public override void _Process(double delta)
    {
        this.Text = $"C#/C++ Add(1, 2) = {Add(1, 2)} in";
        // this.Text = $"{this.count++}";

#if GODOT_WINDOWS
        this.Text += " WIN64";
#elif GODOT_LINUXBSD
        this.Text += " LINUXBSD";
#elif GODOT_OSX
        this.Text += " OSX";
#elif GODOT_ANDROID
		this.Text += " ANDROID";
#elif GODOT_IOS
        this.Text += " IOS";
#elif GODOT_WEB
        this.Text += " WEB";
#endif

#if DEBUG
        this.Text += " DEBUG";
#else
        this.Text += " RELEASE";
#endif
        
    }
}