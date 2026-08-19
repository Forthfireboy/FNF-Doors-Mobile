package backend.assets;

#if !macro
import backend.system.Flags;
import haxe.io.Bytes;
import lime.utils.Assets;
import openfl.Lib;
import openfl.display.BitmapData;
import openfl.display3D.Context3DTextureFormat;
import openfl.display3D.textures.Texture;
import openfl.utils._internal.UInt8Array;

using StringTools;

class ASTCBitmapData {
	static inline var HEADER_SIZE:Int = 16;
	static inline var MAGIC_0:Int = 0x13;
	static inline var MAGIC_1:Int = 0xAB;
	static inline var MAGIC_2:Int = 0xA1;
	static inline var MAGIC_3:Int = 0x5C;

	public static inline function isASTCPath(id:String):Bool {
		return id != null && id.toLowerCase().endsWith('.' + Flags.ASTC_IMAGE_EXT);
	}

	public static function resolveASTCAssetID(id:String):String {
		if (id == null || !Flags.ASTC_TEXTURES)
			return null;
		if (isASTCPath(id))
			return Assets.exists(id) ? id : null;
		if (!Flags.ASTC_PREFER_RUNTIME)
			return null;
		var lower = id.toLowerCase();
		var imageSuffix = '.' + Flags.IMAGE_EXT;
		if (!lower.endsWith(imageSuffix))
			return null;
		var astcID = id.substr(0, id.length - imageSuffix.length) + '.' + Flags.ASTC_IMAGE_EXT;
		return Assets.exists(astcID) ? astcID : null;
	}

	public static function fromAsset(id:String):BitmapData {
		var astcID = resolveASTCAssetID(id);
		if (astcID == null)
			return null;
		var bytes = Assets.getBytes(astcID);
		return fromBytes(bytes, astcID);
	}

	static function fromBytes(bytes:Bytes, assetID:String):BitmapData {
		if (bytes == null || bytes.length <= HEADER_SIZE || !hasValidHeader(bytes)) {
			trace('Invalid ASTC texture: ' + assetID);
			return null;
		}

		var blockX = bytes.get(4);
		var blockY = bytes.get(5);
		var blockZ = bytes.get(6);
		var width = readU24(bytes, 7);
		var height = readU24(bytes, 10);
		var depth = readU24(bytes, 13);
		if (blockZ != 1 || depth != 1 || width <= 0 || height <= 0) {
			trace('Unsupported ASTC texture: ' + assetID + ' (' + blockX + 'x' + blockY + 'x' + blockZ + ', ' + width + 'x' + height + 'x' + depth + ')');
			return null;
		}

		var stage = Lib.current != null ? Lib.current.stage : null;
		var context = stage != null ? stage.context3D : null;
		if (context == null || context.gl == null) {
			trace('ASTC texture requested before Context3D is ready: ' + assetID);
			return null;
		}

		var gl = context.gl;
		var extension = null;
		var extNames = [
			"KHR_texture_compression_astc_ldr",
			"KHR_texture_compression_astc",
			"EXT_texture_compression_astc",
			"WEBGL_compressed_texture_astc",
			"WEBGL_compressed_texture_astc_ldr"
		];
		for (n in extNames) {
			extension = gl.getExtension(n);
			if (extension != null) break;
		}
		if (extension == null) {
			trace('ASTC is not supported by this GPU: ' + assetID);
			return null;
		}

		var numericFormat = getNumericInternalFormat(blockX, blockY);
		if (numericFormat == 0) {
			trace('Unknown ASTC blocksize: ' + blockX + 'x' + blockY + ' for ' + assetID);
			return null;
		}

		var extConst:Int = 0;
		var constNames = [
			"COMPRESSED_RGBA_ASTC_4x4_KHR","COMPRESSED_RGBA_ASTC_5x4_KHR","COMPRESSED_RGBA_ASTC_5x5_KHR",
			"COMPRESSED_RGBA_ASTC_6x5_KHR","COMPRESSED_RGBA_ASTC_6x6_KHR","COMPRESSED_RGBA_ASTC_8x5_KHR",
			"COMPRESSED_RGBA_ASTC_8x6_KHR","COMPRESSED_RGBA_ASTC_8x8_KHR","COMPRESSED_RGBA_ASTC_10x5_KHR",
			"COMPRESSED_RGBA_ASTC_10x6_KHR","COMPRESSED_RGBA_ASTC_10x8_KHR","COMPRESSED_RGBA_ASTC_10x10_KHR",
			"COMPRESSED_RGBA_ASTC_12x10_KHR","COMPRESSED_RGBA_ASTC_12x12_KHR"
		];
		for (i in 0...constNames.length) {
			var nm = constNames[i];
			if (Reflect.hasField(extension, nm)) {
				extConst = Reflect.field(extension, nm);
				break;
			}
		}
		var usedFormat = (extConst != 0) ? extConst : numericFormat;

		try {
			var texture:Texture = context.createTexture(width, height, Context3DTextureFormat.BGRA, false, 0);
			texture.__format = usedFormat;
			texture.__internalFormat = usedFormat;

			context.__bindGLTexture2D(texture.__textureID);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
			gl.compressedTexImage2D(texture.__textureTarget, 0, usedFormat, width, height, 0,
				UInt8Array.fromBytes(bytes, HEADER_SIZE, bytes.length - HEADER_SIZE));
			context.__bindGLTexture2D(null);

			return BitmapData.fromTexture(texture);
		} catch (e:Dynamic) {
			context.__bindGLTexture2D(null);
			trace('Failed to upload ASTC texture ' + assetID + ': ' + e);
			return null;
		}
	}

	static inline function hasValidHeader(bytes:Bytes):Bool {
		return bytes.get(0) == MAGIC_0
			&& bytes.get(1) == MAGIC_1
			&& bytes.get(2) == MAGIC_2
			&& bytes.get(3) == MAGIC_3;
	}

	static inline function readU24(bytes:Bytes, offset:Int):Int {
		return bytes.get(offset) | (bytes.get(offset + 1) << 8) | (bytes.get(offset + 2) << 16);
	}

	static function getNumericInternalFormat(bx:Int, by:Int):Int {
		return switch ('${bx}x${by}') {
			case "4x4": 0x93B0;
			case "5x4": 0x93B1;
			case "5x5": 0x93B2;
			case "6x5": 0x93B3;
			case "6x6": 0x93B4;
			case "8x5": 0x93B5;
			case "8x6": 0x93B6;
			case "8x8": 0x93B7;
			case "10x5": 0x93B8;
			case "10x6": 0x93B9;
			case "10x8": 0x93BA;
			case "10x10": 0x93BB;
			case "12x10": 0x93BC;
			case "12x12": 0x93BD;
			default: 0;
		}
	}
}
#else
class ASTCBitmapData {}
#end
