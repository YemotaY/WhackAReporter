class_name Hammers
extends Node2D

var available_hammers : Array = [
	"Basic_Hammer.svg",
	"German_Hammer.svg",
	"French_Hammer.svg",
	"American_Hammer.svg",
	]

var BASICHAMMER_PRICE = 200
var GERMANHAMMER_PRICE = 200
var FRENCHHAMMER_PRICE = 200
var AMERICANHAMMER_PRICE = 200

var shop_inventory : Array = [
	{
		"name": "BASICHAMMER",
		"description": "BASICHAMMERDESCR",
		"texture": preload("res://assets/hammers/Basic_Hammer.svg")
	},
	{
		"name": "GERMANHAMMER",
		"description": "GERMANHAMMERDESCR",
		"texture": preload("res://assets/hammers/German_Hammer.svg")
	},
	{
		"name": "FRENCHHAMMER",
		"description": "FRENCHHAMMERDESCR",
		"texture": preload("res://assets/hammers/French_Hammer.svg")
	},
	{
		"name": "AMERICANHAMMER",
		"description": "AMERICANHAMMERDESCR",
		"texture": preload("res://assets/hammers/American_Hammer.svg")
	}
]
