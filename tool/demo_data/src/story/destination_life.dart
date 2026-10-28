/// Species from the app's bundled catalogue (`assets/data/species.json`) a
/// diver plausibly meets at each destination, by destination key.
const destinationSpecies = <String, List<String>>{
  'home': ['Northern Pike', 'European Perch', 'Brown Trout', 'Noble Crayfish'],
  'red-sea': [
    'Napoleon Wrasse',
    'Common Lionfish',
    'Giant Moray Eel',
    'Spotted Eagle Ray',
    'Orbicular Batfish',
    'Bottlenose Dolphin',
  ],
  'bali': [
    'Bumphead Parrotfish',
    'Ocellaris Clownfish',
    'Giant Frogfish',
    'Broadclub Cuttlefish',
    'Green Sea Turtle',
  ],
  'cebu': [
    'Green Sea Turtle',
    'Whitetip Reef Shark',
    'Painted Frogfish',
    'Blue-ringed Octopus',
  ],
  'similan': [
    'Whale Shark',
    'Reef Manta Ray',
    "Clark's Clownfish",
    'Leaf Scorpionfish',
  ],
  'maldives': [
    'Reef Manta Ray',
    'Whale Shark',
    'Grey Reef Shark',
    'Hawksbill Sea Turtle',
  ],
  'raja-ampat': [
    'Reef Manta Ray',
    "Bargibant's Pygmy Seahorse",
    'Bumphead Parrotfish',
    'Blacktip Reef Shark',
  ],
  'med': ['Common Octopus', 'Great Barracuda', 'Common Dolphin'],
};

/// The site types of the app's built-in list a destination's sites get.
const destinationSiteTypes = <String, List<String>>{
  'home': ['lake', 'quarry'],
  'red-sea': ['reef', 'wall', 'wreck'],
  'bali': ['reef', 'muck', 'wreck'],
  'cebu': ['reef', 'wall'],
  'similan': ['reef'],
  'maldives': ['reef', 'wall'],
  'raja-ampat': ['reef', 'wall'],
  'med': ['wreck'],
};
