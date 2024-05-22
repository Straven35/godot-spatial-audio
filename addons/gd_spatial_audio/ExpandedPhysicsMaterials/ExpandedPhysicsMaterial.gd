class_name ExpandedPhysicsMaterial
extends PhysicsMaterial

@export var materialName: String = "Default"
@export var footStepSounds: Array[AudioStream]
@export_category("Reverb settings")
## positive value gives reverb; negative value removes reverb.
@export_range(-1,1) var dampening: float = 0.5
## dont look at me
@export_range(0,1) var reverberation: float = 0.5
@export_category("Sound absoprtion coefficients")
# See https://www.acoustic.ua/st/web_absorption_data_eng.pdf for common
# values
@export_range(0, 1) var band_32_hz:float = 0;
@export_range(0, 1) var band_100_hz:float = 0;
@export_range(0, 1) var band_320_hz:float = 0;
@export_range(0, 1) var band_1000_hz:float = 0;
@export_range(0, 1) var band_3200_hz:float = 0;
@export_range(0, 1) var band_10000_hz:float = 0;
