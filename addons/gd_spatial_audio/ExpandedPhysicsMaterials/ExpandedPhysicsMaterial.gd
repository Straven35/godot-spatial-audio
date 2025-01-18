class_name ExpandedPhysicsMaterial
extends PhysicsMaterial

@export var materialName: String = "Default"
@export var footStepSounds: Array[AudioStream]
@export_category("Reverb settings")
## higher is more reverb; lower is less reverb.
@export_range(0,1) var reflection: float = 0.5
## .
@export_range(0,1) var transmission_loss : float = 0.1
@export_category("Sound absorption coefficients")
# See https://www.acoustic.ua/st/web_absorption_data_eng.pdf for common
# values
@export_range(0, 1) var band_32_hz:float = 0;
@export_range(0, 1) var band_100_hz:float = 0;
@export_range(0, 1) var band_320_hz:float = 0;
@export_range(0, 1) var band_1000_hz:float = 0;
@export_range(0, 1) var band_3200_hz:float = 0;
@export_range(0, 1) var band_10000_hz:float = 0;
