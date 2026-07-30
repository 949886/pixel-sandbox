using EarcutDotNet;
using Godot;

/// <summary>
/// Thin Godot bridge around Earcut.NET. The implementation is stateless, so it
/// is safe to call from the collision builder's worker thread.
/// </summary>
[GlobalClass]
public partial class EarcutTriangulator2D : RefCounted
{
    /// <summary>
    /// Triangulates a flattened polygon. vertices contains the outer ring first,
    /// followed by every hole. holeIndices contains the vertex index at which
    /// each hole begins.
    /// </summary>
    public int[] triangulate(Vector2[] vertices, int[] holeIndices)
    {
        if (vertices.Length < 3)
        {
            return [];
        }

        var coordinates = new double[vertices.Length * 2];
        for (var i = 0; i < vertices.Length; i++)
        {
            coordinates[i * 2] = vertices[i].X;
            coordinates[i * 2 + 1] = vertices[i].Y;
        }

        return Earcut.Triangulate(coordinates, holeIndices, 2);
    }
}
