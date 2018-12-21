package openfl._internal.stage3D.opengl;


import haxe.io.Bytes;
import lime.utils.ArrayBufferView;
import lime.utils.UInt8Array;
import openfl._internal.renderer.RenderSession;
import openfl._internal.stage3D.atf.ATFReader;
import openfl._internal.stage3D.GLUtils;
import openfl._internal.stage3D.SamplerState;
import openfl.display3D.textures.Texture;
import openfl.display3D.textures.TextureBase;
import openfl.display3D.Context3D;
import openfl.display.BitmapData;
import openfl.errors.IllegalOperationError;
import openfl.utils.ByteArray;

#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end

@:access(openfl._internal.stage3D.SamplerState)
@:access(openfl.display3D.textures.Texture)
@:access(openfl.display3D.Context3D)


class GLTexture {
	
	
	public static function create (texture:Texture, renderSession:RenderSession):Void {
		
		var gl = renderSession.gl;
		
		texture.__textureTarget = gl.TEXTURE_2D;
		
		gl.bindTexture (texture.__textureTarget, texture.__textureData.glTexture);
		GLUtils.CheckGLError ();
		
		gl.texImage2D (texture.__textureTarget, 0, texture.__internalFormat, texture.__width, texture.__height, 0, texture.__format, gl.UNSIGNED_BYTE, null);
		GLUtils.CheckGLError ();
		
		gl.bindTexture (texture.__textureTarget, null);
		
		uploadFromTypedArray (texture, renderSession, null);
		
	}
	
	
	public static function uploadCompressedTextureFromByteArray (texture:Texture, renderSession:RenderSession, data:ByteArray, byteArrayOffset:UInt):Void {
		
		var reader = new ATFReader(data, byteArrayOffset);
		var alpha = reader.readHeader (texture.__width, texture.__height, false);
		
		var gl = renderSession.gl;
		
		gl.bindTexture (texture.__textureTarget, texture.__textureData.glTexture);
		GLUtils.CheckGLError ();
		
		var hasTexture = false;
		
		reader.readTextures (function (target, level, gpuFormat, width, height, blockLength, bytes) {
			
			var format = GLTextureBase.__compressedTextureFormats.toTextureFormat (alpha, gpuFormat);
			if (format == 0) return;
			
			hasTexture = true;
			texture.__format = format;
			texture.__internalFormat = format;
			
			gl.compressedTexImage2D (texture.__textureTarget, level, texture.__internalFormat, width, height, 0, blockLength, bytes);
			GLUtils.CheckGLError ();
			
			// __trackCompressedMemoryUsage (blockLength);
			
		});
		
		if (!hasTexture) {
			
			var data = new UInt8Array (texture.__width * texture.__height * 4);
			gl.texImage2D (texture.__textureTarget, 0, texture.__internalFormat, texture.__width, texture.__height, 0, texture.__format, gl.UNSIGNED_BYTE, data);
			GLUtils.CheckGLError ();
			
		}
		
		gl.bindTexture (texture.__textureTarget, null);
		GLUtils.CheckGLError ();
		
	}
	
	
	public static function uploadFromBitmapData (texture:Texture, renderSession:RenderSession, source:BitmapData, miplevel:UInt, generateMipmap:Bool):Void {
		
		/* TODO
			if (LowMemoryMode) {
				// shrink bitmap data
				source = source.shrinkToHalfResolution();
				// shrink our dimensions for upload
				width = source.width;
				height = source.height;
			}
			*/
		
		if (source == null) return;
		
		var width = texture.__width >> miplevel;
		var height = texture.__height >> miplevel;
		
		if (width == 0 && height == 0) return;
		
		if (width == 0) width = 1;
		if (height == 0) height = 1;
		
		if (source.width != width || source.height != height) {
			
			var copy = new BitmapData (width, height, true, 0);
			copy.draw (source);
			source = copy;
			
		}
		
		var image = texture.__getImage (source);
		
		uploadFromTypedArray (texture, renderSession, image.data, miplevel);
		
	}
	
	
	public static function uploadFromByteArray (texture:Texture, renderSession:RenderSession, data:ByteArray, byteArrayOffset:UInt, miplevel:UInt = 0):Void {
		
		#if js
		if (byteArrayOffset == 0) {
			
			uploadFromTypedArray (texture, renderSession, @:privateAccess (data:ByteArrayData).b, miplevel);
			return;
			
		}
		#end
		
		uploadFromTypedArray (texture, renderSession, new UInt8Array (data.toArrayBuffer (), byteArrayOffset), miplevel);
		
	}
	
	
	public static function uploadFromTypedArray (texture:Texture, renderSession:RenderSession, data:ArrayBufferView, miplevel:UInt = 0):Void {
		
		if (data == null) return;
		var gl = renderSession.gl;
		
		var width = texture.__width >> miplevel;
		var height = texture.__height >> miplevel;
		
		if (width == 0 && height == 0) return;
		
		if (width == 0) width = 1;
		if (height == 0) height = 1;
		
		gl.bindTexture (texture.__textureTarget, texture.__textureData.glTexture);
		GLUtils.CheckGLError ();
		
		gl.texImage2D (texture.__textureTarget, miplevel, texture.__internalFormat, width, height, 0, texture.__format, gl.UNSIGNED_BYTE, data);
		GLUtils.CheckGLError ();
		
		gl.bindTexture (texture.__textureTarget, null);
		GLUtils.CheckGLError ();
		
		// var memUsage = (width * height) * 4;
		// __trackMemoryUsage (memUsage);
		
	}
	
	
	public static function setSamplerState (texture:Texture, renderSession:RenderSession, state:SamplerState) {
		
		if (!state.equals (texture.__samplerState)) {
			
			var gl = renderSession.gl;
			
			if (state.minFilter != gl.NEAREST && state.minFilter != gl.LINEAR && !state.mipmapGenerated) {
				
				gl.generateMipmap (gl.TEXTURE_2D);
				GLUtils.CheckGLError ();
				
				state.mipmapGenerated = true;
				
			}
			
			if (state.maxAniso != 0.0) {
				
				gl.texParameterf (gl.TEXTURE_2D, Context3D.TEXTURE_MAX_ANISOTROPY_EXT, state.maxAniso);
				GLUtils.CheckGLError ();
				
			}
			
		}
		
		GLTextureBase.setSamplerState (texture, renderSession, state);
		
	}
	
	
}