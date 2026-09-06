class_name RushReleaseInfo
extends RefCounted
static func config() -> Dictionary:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://config/release.json"))
 return data if data is Dictionary else {}
static func version() -> String:
 var data:=config()
 return "v%s · Build %d · %s"%[data.get("version","unknown"),data.get("build",0),"PLAYTEST" if OS.has_feature("playtest") or OS.is_debug_build() else "RELEASE CANDIDATE"]
static func diagnostics() -> String:
 return "RingRush / %s\nPlatform: %s\nRenderer: %s\nPlease describe the issue and steps to reproduce."%[version(),OS.get_name(),RenderingServer.get_current_rendering_method()]
static func credits() -> Array:
 return [
  {"title":"FIGHTERS & ANIMATIONS","author":"Quaternius · CC0","detail":"Universal Base Characters / Universal Animation Library. Meshes, clothing and selected animations adapted.","url":"https://quaternius.com/packs/universalbasecharacters.html","license":""},
  {"title":"ANIMATION LIBRARY","author":"Quaternius · CC0","detail":"Universal Animation Library. Compatible tracks assembled from the Quaternius IK Rigged distribution.","url":"https://quaternius.com/packs/universalanimationlibrary.html","license":""},
  {"title":"ROBOT FIGHTERS","author":"Quaternius · CC0","detail":"Ultimate Space Kit: 3 mech chassis. Modified helmets, boxing arms and weapon mounts.","url":"https://quaternius.com/packs/ultimatespacekit.html","license":""},
  {"title":"MONSTERS & ARC BEE","author":"Quaternius · CC0","detail":"Ultimate Monsters: GreenSpikyBlob, Ghost, Armabee. Scale, color and animation pose bakes adapted.","url":"https://quaternius.com/packs/ultimatemonsters.html","license":"res://assets/creatures/Monsters-LICENSE.txt"},
  {"title":"WOLF, FOX & SHIBA","author":"Quaternius · CC0","detail":"Ultimate Animated Animals: Wolf, Fox, ShibaInu. Shared pose bakes for enemies and companions.","url":"https://quaternius.com/packs/ultimateanimatedanimals.html","license":"res://assets/creatures/Animals-LICENSE.txt"},
  {"title":"FLYING DRONES","author":"Quaternius · CC0","detail":"Cyberpunk Game Kit: Enemy_Flying and Enemy_Flying_Gun. Animation and geometry adapted.","url":"https://quaternius.com/packs/cyberpunkgamekit.html","license":"res://assets/creatures/Cyberpunk-LICENSE.txt"},
  {"title":"RIFT SKELETONS","author":"Kay Lousberg · CC0","detail":"KayKit Character Pack: Skeletons 1.0. Minion, Rogue and Mage appear only as Rift enemies.","url":"https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0","license":"res://assets/fighters/kaykit/LICENSE.txt"},
  {"title":"BARLOW CONDENSED","author":"Jeremy Tribby · SIL OFL 1.1","detail":"Display typeface. Godot's bundled Noto Sans font notices are included in engine dependencies.","url":"https://github.com/jpt/barlow","license":"res://assets/fonts/OFL-BarlowCondensed.txt"},
  {"title":"GODOT ENGINE","author":"Godot contributors · MIT","detail":"Godot 4.5.1. Engine and third-party dependency notices included below.","url":"https://godotengine.org/license/","license":"res://assets/licenses/Godot-LICENSE.txt"},
  {"title":"GODOT DEPENDENCIES","author":"Various contributors","detail":"Full copyright and license notices for engine dependencies.","url":"https://godotengine.org/license/","license":"res://assets/licenses/Godot-COPYRIGHT.txt"},
  {"title":"RINGRUSH","author":"ZX Labs","detail":"Game code, arenas, adapted wardrobes, procedural effects, original synthesized music and sound effects.","url":"https://www.zxlabs.dev","license":""}
 ]
