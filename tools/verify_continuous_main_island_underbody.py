import json

import bpy


CLIFF_NAME = "V2CentralCliff"
FORBIDDEN_PREFIXES = (
    "V10CentralSouthCliffFacet_",
    "V10CentralEastCliffFacet_",
    "V10NorthIslandFrontCliffFacet_",
)


def connected_component_count(mesh):
    adjacency = [set() for _vertex in mesh.vertices]
    for edge in mesh.edges:
        first, second = edge.vertices
        adjacency[first].add(second)
        adjacency[second].add(first)
    remaining = set(range(len(mesh.vertices)))
    components = 0
    while remaining:
        components += 1
        pending = [remaining.pop()]
        while pending:
            current = pending.pop()
            for neighbor in adjacency[current]:
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    pending.append(neighbor)
    return components


def main():
    cliff = bpy.data.objects.get(CLIFF_NAME)
    if cliff is None or cliff.type != "MESH":
        raise RuntimeError(f"Missing continuous cliff mesh: {CLIFF_NAME}")
    forbidden = [
        obj.name
        for obj in bpy.context.scene.objects
        if obj.type == "MESH" and obj.name.startswith(FORBIDDEN_PREFIXES)
    ]
    if forbidden:
        raise RuntimeError(f"Detached cliff modules remain: {forbidden}")
    components = connected_component_count(cliff.data)
    if components != 1:
        raise RuntimeError(f"Central underbody has {components} disconnected mesh components")
    coordinates = [vertex.co for vertex in cliff.data.vertices]
    extents = {
        "width": max(point.x for point in coordinates) - min(point.x for point in coordinates),
        "depth": max(point.y for point in coordinates) - min(point.y for point in coordinates),
        "height": max(point.z for point in coordinates) - min(point.z for point in coordinates),
    }
    if extents["width"] < 54.0 or extents["depth"] < 34.0 or extents["height"] < 9.0:
        raise RuntimeError(f"Central underbody no longer spans the main island: {extents}")
    print("MAIN_ISLAND_UNDERBODY=" + json.dumps({
        "mesh": CLIFF_NAME,
        "components": components,
        "forbidden_modules": len(forbidden),
        "extents": extents,
    }, sort_keys=True))


if __name__ == "__main__":
    main()
