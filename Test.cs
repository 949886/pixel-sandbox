using Godot;
using System;

public partial class Test : Label
{
	int count = 0;

	public override void _Ready()
	{
	}

	public override void _Process(double delta)
	{
		this.Text = $"{this.count++}";
	}
}
