package backend.system;

class Flags
{
    // Keep canonical image extension
    public static inline var IMAGE_EXT:String = "png";

    // ASTC settings
    public static inline var ASTC_IMAGE_EXT:String = "astc";

    // Enable ASTC runtime usage only on android by default
    public static inline var ASTC_TEXTURES:Bool = #if android true #else false #end;
    public static inline var ASTC_PREFER_RUNTIME:Bool = #if android true #else false #end;
}
