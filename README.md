# Dons - Procedural City Generator

A procedural city generator built with Godot 4.3+ featuring dynamic neighborhoods, rivers, bridges, parks, and autonomous agents.

## Features

- **Procedural City Generation**: Creates realistic city layouts with roads, sidewalks, and building blocks
- **Neighborhoods**: Three distinct districts (Downtown, Little Italy, Chinatown) with unique characteristics
- **Natural Features**: Rivers with bridges, parks with pathways
- **Building Types**: Residential, Commercial, Industrial, Office, and Institutional buildings (Schools, Hospitals, Churches, Police/Fire Stations)
- **Autonomous Agents**: 50 simulated agents that travel between home and work
- **Interactive Camera**: Pan (WASD/Arrows or Right-Click), Zoom (Mouse Wheel), and regenerate cities (SPACE)

## Getting Started

1. Open the project in Godot 4.3 or later
2. Run the project (F5)
3. Use the controls below to explore

## Controls

- **WASD / Arrow Keys**: Pan camera
- **Mouse Wheel**: Zoom in/out
- **Right-Click + Drag**: Pan camera with mouse
- **SPACE**: Generate a new random city
- **R**: Regenerate city with the same seed (if seed_value is set)
- **C**: Center camera

## Customization

Edit the exported variables in the Inspector or `scripts/city_generator.gd`:

- `city_size`: Overall city dimensions (default: 800x800)
- `block_size`: Size of each city block (default: 40x40)
- `road_width`: Width of roads (default: 6.0)
- `building_density`: Probability of buildings appearing (default: 0.9)
- `num_agents`: Number of simulated agents (default: 50)
- `seed_value`: Fixed seed for reproducible generation (0 = random)

## Code Improvements

This version includes several optimizations:
- Dictionary-based park block lookup for O(1) performance
- Consistent river wave generation using fixed frequency
- Seeded random number generation for reproducible cities
- Improved variable naming to avoid shadowing

## License

MIT License