class_name ExpandedPhysicsMaterial
extends PhysicsMaterial

@export var materialName: String = "Default"
@export var footStepSounds: Array[AudioStream]
@export_category("Reverb settings")
## higher lets in more reverb; lower absorbs reverb.
@export_range(0,1) var damping: float = 0.5
## higher adds more wetness.
@export_range(0,1) var transmission : float = 0.5
@export_category("Sound absoprtion coefficients")
# See https://www.acoustic.ua/st/web_absorption_data_eng.pdf for common
# values
@export_range(0, 1) var band_32_hz:float = 0;
@export_range(0, 1) var band_100_hz:float = 0;
@export_range(0, 1) var band_320_hz:float = 0;
@export_range(0, 1) var band_1000_hz:float = 0;
@export_range(0, 1) var band_3200_hz:float = 0;
@export_range(0, 1) var band_10000_hz:float = 0;
