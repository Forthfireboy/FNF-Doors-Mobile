package;

import flxanimate.FlxAnimate;
import haxe.io.Bytes;
import animateatlas.AtlasFrameMaker;
import flixel.math.FlxPoint;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import openfl.geom.Rectangle;
import flixel.math.FlxRect;
import haxe.xml.Access;
import openfl.system.System;
import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import lime.utils.Assets;
import flixel.FlxSprite;
#if sys
import sys.io.File;
import sys.FileSystem;
#end
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import haxe.Json;
import openfl.display3D.textures.RectangleTexture;

import flash.media.Sound;

using StringTools;

import backend.system.Flags;
import backend.assets.ASTCBitmapData;

class Paths
{
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;
	inline public static var VIDEO_EXT = "mp4";

	#if MODS_ALLOWED
	public static var ignoreModFolders:Array<String> = [
		'characters',
		'custom_events',
		'custom_notetypes',
		'data',
		'songs',
		'music',
		'sounds',
		'shaders',
		'videos',
		'images',
		'stages',
		'weeks',
		'fonts',
		'scripts',
		'achievements'
	];
	#end

	public static function excludeAsset(key:String) {
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}
	
	public static function excludeBitmap(key:FlxGraphic) {
		//try to convert key to flxgraphic, if it's a BitmapData or something idk
		if (!excludedBitmaps.contains(key))
			excludedBitmaps.push(key);
	}

	private static var debugShitThis:Bool = false;
	private static var loadedPaths:Array<String> = [];

	public static var dumpExclusions:Array<String> =
	[
		'assets/music/freakyMenu.$SOUND_EXT',
		'assets/music/freakyMenuLoop.$SOUND_EXT',
		'assets/music/freakyOptions.$SOUND_EXT',
		'assets/music/SillyPause.$SOUND_EXT',
	];

	public static var excludedBitmaps:Array<FlxGraphic> = [];

	/// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory() {
		// clear non local assets in the tracked assets list
		for (key in currentTrackedAssets.keys()) {
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key)
				&& !dumpExclusions.contains(key)) {
				// get rid of it
				var obj = currentTrackedAssets.get(key);
				@:privateAccess
				if (obj != null && !excludedBitmaps.contains(obj)) {
					FlxG.bitmap._cache.remove(key);
					openfl.Assets.cache.removeBitmapData(key);
					currentTrackedAssets.remove(key);

					obj.persist = false; // make sure the garbage collector actually clears it up
					obj.destroyOnNoUse = true;
					obj.destroy();
				}
			}
		}
		// run the garbage collector for good measure lmfao
		System.gc();
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = [];

	@:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
	public static function clearStoredMemory(?cleanUnused:Bool = false) {
		// clear anything not in the tracked assets list
		@:privateAccess
		for (key in FlxG.bitmap._cache.keys())
		{
			var obj = FlxG.bitmap._cache.get(key);
			if (obj != null && !excludedBitmaps.contains(obj) && !currentTrackedAssets.exists(key)) {
				openfl.Assets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);
				obj.destroy();
			}
		}

		// clear all sounds that are cached
		for (key => asset in currentTrackedSounds)
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && asset != null)
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}
		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = [];
		#if !html5 openfl.Assets.cache.clear("songs"); #end

		if(cleanUnused) clearUnusedMemory();
	}

	static public var currentModDirectory:String = '';
	static public var currentLevel:String;
	static public function setCurrentLevel(name:String)
	{
		currentLevel = name.toLowerCase();
	}

	public static function getPath(file:String, type:AssetType, ?library:Null<String> = null)
	{
		if(debugShitThis)
		{
			if(!loadedPaths.contains(file))
			{
				loadedPaths.push(file);
				trace(file);
			}
		}

		if (library != null)
			return getLibraryPath(file, library);

		if (currentLevel != null)
		{
			var levelPath:String = '';
			if(currentLevel != 'shared') {
				levelPath = getLibraryPathForce(file, currentLevel);
				if (OpenFlAssets.exists(levelPath, type))
					return levelPath;
			}

			levelPath = getLibraryPathForce(file, "shared");
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}

		return getPreloadPath(file);
	}

	static public function getLibraryPath(file:String, library = "preload")
	{
		return if (library == "preload" || library == "default") getPreloadPath(file); else getLibraryPathForce(file, library);
	}

	inline public static function getSharedPath(file:String = '')
	{
		return 'assets/shared/$file';
	}

	inline static function getLibraryPathForce(file:String, library:String)
	{
		var returnPath = '$library:assets/$library/$file';
		return returnPath;
	}

	inline public static function getPreloadPath(file:String = '')
	{
		return 'assets/$file';
	}

	inline public static function file(file:String, type:AssetType = TEXT, ?library:String)
	{
		return getPath(file, type, library);
	}

	inline public static function txt(key:String, ?library:String)
	{
		return getPath('data/$key.txt', TEXT, library);
	}

	inline public static function xml(key:String, ?library:String)
	{
		return getPath('data/$key.xml', TEXT, library);
	}

	inline public static function json(key:String, ?library:String)
	{
		return getPath('data/$key.json', TEXT, library);
	}

	inline public static function shaderFragment(key:String, ?library:String)
	{
		return getPath('shaders/$key.frag', TEXT, library);
	}

	inline public static function shaderVertex(key:String, ?library:String)
	{
		return getPath('shaders/$key.vert', TEXT, library);
	}

	inline public static function lua(key:String, ?library:String)
	{
		return getPath('$key.lua', TEXT, library);
	}

	inline public static function gif(key:String, ?library:String)
	{
		return getPath('$key.gif', BINARY, library);
	}

	
	
	static public function video(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsVideo(key);
		if(FileSystem.exists(file)) {
			return file;
		}
		#end
		return Asset2File.getPath('assets/videos/$key.$VIDEO_EXT');
	}

	static public function sound(key:String, ?library:String):Sound
	{
		var sound:Sound = returnSound('sounds', key, library);
		return sound;
	}

	inline public static function soundRandom(key:String, min:Int, max:Int, ?library:String)
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	inline public static function music(key:String, ?library:String):Sound
	{
		var file:Sound = returnSound('music', key, library);
		return file;
	}

	inline public static function voices(song:String):Any
	{
		var voices = wackyFix(song, 'voices');
		return voices;
	}

	inline public static function inst(song:String):Any
	{
		var inst = wackyFix(song, 'inst');
		return inst;
	}

	static public function wackyFix(songName:String, type:String)
	{
		var songKey:String = '${formatToSongPath(songName)}/${type == 'inst' ? 'Inst' : 'Voices'}';
		var gottenPath:String = getPath('songs/$songKey.$SOUND_EXT', SOUND);
		gottenPath = gottenPath.substring(gottenPath.indexOf(':') + 1, gottenPath.length);

		if(!OpenFlAssets.exists('songs:' + getPath('songs/$songKey.$SOUND_EXT', SOUND), SOUND))
		{
			songKey = '${formatToSongPath(songName)}/${type == 'inst' ? 'inst' : 'voices'}';
			trace(getPath('songs/$songKey.$SOUND_EXT', SOUND));
			return returnSound('songs', songKey);
		}
		return returnSound('songs', songKey);
	}

	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	static public function image(key:String, ?library:String = null, ?allowGPU:Bool = true):FlxGraphic
	{
		var bitmap:BitmapData = null;
		var file:String = null;

		#if MODS_ALLOWED
		file = modsImages(key);
		if (currentTrackedAssets.exists(file))
		{
			localTrackedAssets.push(file);
			return currentTrackedAssets.get(file);
		}
		else if (FileSystem.exists(file))
			bitmap = BitmapData.fromFile(file);
		else
		#end
		{
			// Try runtime ASTC when available & enabled
			if (Flags.ASTC_TEXTURES && Flags.ASTC_PREFER_RUNTIME)
			{
				var astcPath = getPath('images/$key.' + Flags.ASTC_IMAGE_EXT, IMAGE, library);
				if (astcPath != null && OpenFlAssets.exists(astcPath, IMAGE))
				{
					var astcBitmap = ASTCBitmapData.fromAsset(astcPath);
					if (astcBitmap != null)
					{
						bitmap = astcBitmap;
						file = astcPath;
					}
				}
			}

			// If ASTC not used / failed, fallback to PNG
			if (bitmap == null)
			{
				file = getPath('images/$key.png', IMAGE, library);
				if (currentTrackedAssets.exists(file))
				{
					localTrackedAssets.push(file);
					return currentTrackedAssets.get(file);
				}
				else if (OpenFlAssets.exists(file, IMAGE))
					bitmap = OpenFlAssets.getBitmapData(file);
			}
		}

		if (bitmap != null)
		{
			localTrackedAssets.push(file);
			if (allowGPU && ClientPrefs.data.cacheOnGPU)
			{
				var isGPUOnly:Bool = false;
				try {
					isGPUOnly = (bitmap != null && Reflect.hasField(bitmap, "__texture") && Reflect.field(bitmap, "__texture") != null);
				} catch(e:Dynamic) { isGPUOnly = false; }

				if (!isGPUOnly)
				{
					var texture:RectangleTexture = FlxG.stage.context3D.createRectangleTexture(bitmap.width, bitmap.height, BGRA, true);
					texture.uploadFromBitmapData(bitmap);
					bitmap.image.data = null;
					bitmap.dispose();
					bitmap.disposeImage();
					bitmap = BitmapData.fromTexture(texture);
				}
			}
			var newGraphic:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, file);
			newGraphic.persist = true;
			newGraphic.destroyOnNoUse = false;
			currentTrackedAssets.set(file, newGraphic);
			return newGraphic;
		}

		trace('oh no its returning null NOOOO ($file)');
		return null;
	}

	static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		#if sys
		#if MODS_ALLOWED
		if (!ignoreMods && FileSystem.exists(modFolders(key)))
			return File.getContent(modFolders(key));
		#end

		if (FileSystem.exists(getSharedPath(key)))
			return File.getContent(getSharedPath(key));

		if (currentLevel != null)
		{
			var levelPath:String = '';
			if(currentLevel != 'shared') {
				levelPath = getLibraryPathForce(key, currentLevel);
				if (FileSystem.exists(levelPath))
					return File.getContent(levelPath);
			}
		}
		#end
		var path:String = getPath(key, TEXT);
		if(OpenFlAssets.exists(path, TEXT)) return Assets.getText(path);
		return null;
	}

	inline static public function font(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsFont(key);
		if(FileSystem.exists(file)) {
			return file;
		}
		#end
		return 'assets/fonts/$key';
	}

	inline public static function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?library:String)
	{
		#if MODS_ALLOWED
		if(FileSystem.exists(mods(currentModDirectory + '/' + key)) || FileSystem.exists(mods(key))) {
			return true;
		}
		#end

		if(OpenFlAssets.exists(getPath(key, type))) {
			return true;
		}
		return false;
	}

	inline static public function getSparrowAtlas(key:String, ?library:String, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		#if MODS_ALLOWED
		var imageLoaded:FlxGraphic = image(key, allowGPU);
		var xmlExists:Bool = false;
		if(FileSystem.exists(modsXml(key))) {
			xmlExists = true;
		}

		return FlxAtlasFrames.fromSparrow((imageLoaded != null ? imageLoaded : image(key, library, allowGPU)), (xmlExists ? File.getContent(modsXml(key)) : file('images/$key.xml', library)));
		#else
		return FlxAtlasFrames.fromSparrow(image(key, library), file('images/$key.xml', library));
		#end
	}


	inline static public function getPackerAtlas(key:String, ?library:String, ?allowGPU:Bool = true)
	{
		#if MODS_ALLOWED
		var imageLoaded:FlxGraphic = image(key, allowGPU);
		var txtExists:Bool = false;
		if(FileSystem.exists(modsTxt(key))) {
			txtExists = true;
		}

		return FlxAtlasFrames.fromSpriteSheetPacker((imageLoaded != null ? imageLoaded : image(key, library, allowGPU)), (txtExists ? File.getContent(modsTxt(key)) : file('images/$key.txt', library)));
		#else
		return FlxAtlasFrames.fromSpriteSheetPacker(image(key, library), file('images/$key.txt', library));
		#end
	}

	inline static public function formatToSongPath(path:String) {
		var invalidChars = ~/[~&\\;:<>#]/;
		var hideChars = ~/[.,'"%?!]/;

		var path = invalidChars.split(path.replace(' ', '-')).join("-");
		return hideChars.split(path).join("").toLowerCase();
	}

	public static var currentTrackedSounds:Map<String, Sound> = [];
	public static function returnSound(path:String, key:String, ?library:String) {
		try {
			#if MODS_ALLOWED
			var file:String = modsSounds(path, key);
			if(FileSystem.exists(file)) {
				if(!currentTrackedSounds.exists(file)) {
					currentTrackedSounds.set(file, Sound.fromFile(file));
				}
				localTrackedAssets.push(key);
				return currentTrackedSounds.get(file);
			}
			#end
			// I hate this so god damn much
			var gottenPath:String = getPath('$path/$key.$SOUND_EXT', SOUND, library);
			gottenPath = gottenPath.substring(gottenPath.indexOf(':') + 1, gottenPath.length);
			// trace(gottenPath);
			if(!currentTrackedSounds.exists(gottenPath))
			#if MODS_ALLOWED
				currentTrackedSounds.set(gottenPath, Sound.fromFile(gottenPath));
			#else
			{
				var folder:String = '';
				if(path == 'songs') folder = 'songs:';

				currentTrackedSounds.set(gottenPath, OpenFlAssets.getSound(folder + getPath('$path/$key.$SOUND_EXT', SOUND, library)));
			}
			#end
			localTrackedAssets.push(gottenPath);
			return currentTrackedSounds.get(gottenPath);
		} catch(e) { trace(e); return null; }
	}

	#if MODS_ALLOWED
	inline static public function mods(key:String = '') {
		return 'mods/' + key;
	}

	inline static public function modsFont(key:String) {
		return modFolders('fonts/' + key);
	}

	inline static public function modsJson(key:String) {
		return modFolders('data/' + key + '.json');
	}

	inline static public function modsVideo(key:String) {
		return modFolders('videos/' + key + '.' + VIDEO_EXT);
	}

	inline static public function modsSounds(path:String, key:String) {
		return modFolders(path + '/' + key + '.' + SOUND_EXT);
	}

	inline static public function modsImages(key:String, prefix:String = "images/") {
		return modFolders(prefix + key + '.png');
	}

	inline static public function modsXml(key:String) {
		return modFolders('images/' + key + '.xml');
	}

	inline static public function modsTxt(key:String) {
		return modFolders('images/' + key + '.txt');
	}

	/* Goes unused for now

	inline static public function modsShaderFragment(key:String, ?library:String)
	{
		return modFolders('shaders/'+key+'.frag');
	}
	inline static public function modsShaderVertex(key:String, ?library:String)
	{
		return modFolders('shaders/'+key+'.vert');
	}
	inline static public function modsAchievements(key:String) {
		return modFolders('achievements/' + key + '.json');
	}*/

	static public function modFolders(key:String) {
		if(currentModDirectory != null && currentModDirectory.length > 0) {
			var fileToCheck:String = mods(currentModDirectory + '/' + key);
			if(FileSystem.exists(fileToCheck)) {
				return fileToCheck;
			}
		}

		for(mod in getGlobalMods()){
			var fileToCheck:String = mods(mod + '/' + key);
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;
		
		}
		return 'mods/' + key;
	}

	public static var globalMods:Array<String> = [];

	static public function getGlobalMods()
		return globalMods;

	static public function pushGlobalMods() // prob a better way to do this but idc
	{
		globalMods = [];
		var path:String = 'modsList.txt';
		if(FileSystem.exists(path))
		{
			var list:Array<String> = CoolUtil.coolTextFile(path);
			for (i in list)
			{
				var dat = i.split("|");
				if (dat[1] == "1")
				{
					var folder = dat[0];
					var path = Paths.mods(folder + '/pack.json');
					if(FileSystem.exists(path)) {
						try{
							var rawJson:String = File.getContent(path);
							if(rawJson != null && rawJson.length > 0) {
								var stuff:Dynamic = Json.parse(rawJson);
								var global:Bool = Reflect.getProperty(stuff, "runsGlobally");
								if(global)globalMods.push(dat[0]);
							}
						} catch(e:Dynamic){
							trace(e);
						}
					}
				}
			}
		}
		return globalMods;
	}

	static public function getModDirectories():Array<String> {
		var list:Array<String> = [];
		var modsFolder:String = mods();
		if(FileSystem.exists(modsFolder)) {
			for (folder in FileSystem.readDirectory(modsFolder)) {
				var path = haxe.io.Path.join([modsFolder, folder]);
				if (sys.FileSystem.isDirectory(path) && !ignoreModFolders.contains(folder) && !list.contains(folder)) {
					list.push(folder);
				}
			}
		}
		return list;
	}
	#end

	static public function getBytes(key:String, ?ignoreMods:Bool = false):Bytes
	{
		#if sys
		#if MODS_ALLOWED
		if (!ignoreMods && FileSystem.exists(modFolders(key)))
			return File.getBytes(modFolders(key));
		#end

		if (FileSystem.exists(getPreloadPath(key)))
			return File.getBytes(getPreloadPath(key));

		if (currentLevel != null)
		{
			var levelPath:String = '';
			if(currentLevel != 'shared') {
				levelPath = getLibraryPathForce(key, currentLevel);
				if (FileSystem.exists(levelPath))
					return File.getBytes(levelPath);
			}

			levelPath = getLibraryPathForce(key, 'shared');
			if (FileSystem.exists(levelPath))
				return File.getBytes(levelPath);
		}
		#end
		return Assets.getBytes(getPath(key, TEXT));
	}

	static public function exists(key:String, ?ignoreMods:Bool = false):Bool
	{
		#if sys
		#if MODS_ALLOWED
		if (!ignoreMods && FileSystem.exists(modFolders(key)))
			return true;
		#end

		if (FileSystem.exists(getPreloadPath(key)))
			return true;

		if (currentLevel != null)
		{
			var levelPath:String = '';
			if(currentLevel != 'shared') {
				levelPath = getLibraryPathForce(key, currentLevel);
				if (FileSystem.exists(levelPath))
					return true;
			}

			levelPath = getLibraryPathForce(key, 'shared');
			if (FileSystem.exists(levelPath))
				return true;
		}
		#end
		return Assets.exists(getPath(key, TEXT));
	}

	static public function getText(key:String, ?ignoreMods:Bool = false) {
		return getTextFromFile(key, ignoreMods);
	}

	public static function loadAnimateAtlas(spr:FlxAnimate, folderOrImg:Dynamic, spriteJson:Dynamic = null, animationJson:Dynamic = null)
		{
			var changedAnimJson = false;
			var changedAtlasJson = false;
			var changedImage = false;
			
			if(spriteJson != null)
			{
				changedAtlasJson = true;
				spriteJson = File.getContent(spriteJson);
			}
	
			if(animationJson != null) 
			{
				changedAnimJson = true;
				animationJson = File.getContent(animationJson);
			}
	
			// is folder or image path
			if(Std.isOfType(folderOrImg, String))
			{
				var originalPath:String = folderOrImg;
				for (i in 0...10)
				{
					var st:String = '$i';
					if(i == 0) st = '';
			
					if(!changedAtlasJson)
					{
						spriteJson = getTextFromFile('images/$originalPath/spritemap$st.json');
						if(spriteJson != null)
						{
							changedImage = true;
							changedAtlasJson = true;
							folderOrImg = Paths.image('$originalPath/spritemap$st');
							break;
						}
					}
					else if(Paths.fileExists('images/$originalPath/spritemap$st.png', IMAGE))
					{
						changedImage = true;
						folderOrImg = Paths.image('$originalPath/spritemap$st');
						break;
					}
				}
			
				if(!changedImage)
				{
					changedImage = true;
					folderOrImg = Paths.image(originalPath);
				}
			
				if(!changedAnimJson)
				{
					changedAnimJson = true;
					animationJson = getTextFromFile('images/$originalPath/Animation.json');
				}
			}
	
			spr.loadAtlasEx(folderOrImg, spriteJson, animationJson);
		}

	static public function getAtlas(key:String, ?library:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
		{
			var useMod = false;
			var imageLoaded:FlxGraphic = image(key, library, allowGPU);
	
			var myXml:Dynamic = getPath('images/$key.xml', TEXT, library);
			if(OpenFlAssets.exists(myXml) #if MODS_ALLOWED || (FileSystem.exists(myXml) && (useMod = true)) #end )
			{
				return FlxAtlasFrames.fromSparrow(imageLoaded, myXml);
			}
			else
			{
				var myJson:Dynamic = getPath('images/$key.json', TEXT, library);
				if(OpenFlAssets.exists(myJson) #if MODS_ALLOWED || (FileSystem.exists(myJson) && (useMod = true)) #end )
				{
					return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, myJson);
				}
			}
			return getPackerAtlas(key, library);
		}
}
