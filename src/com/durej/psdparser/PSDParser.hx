package com.durej.psdparser;

 import flash.display.BitmapData;
 import flash.utils.ByteArray;
 /**
 * com.durej.PSDParser  
 *  
 * @author       Copyright (c) 2010 Slavomir Durej
 * @version      0.1
 *  
 * @link         http://durej.com/
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); 
 * you may not use this file except in compliance with the License. 
 * You may obtain a copy of the License at 
 *  
 * http://www.apache.org/licenses/LICENSE-2.0 
 *  
 * Unless required by applicable law or agreed to in writing, software 
 * distributed under the License is distributed on an "AS IS" BASIS, 
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,  
 * either express or implied. See the License for the specific language 
 * governing permissions and limitations under the License. 
 */
class PSDParser 
{
	public static var instance 			: PSDParser;
	
	//compression types
	private static inline var COMP_RAW 				: Int = 0;		//Raw image data
	private static inline var COMP_RLE 				: Int = 1;		//RLE compressed the image
	private static inline var COMP_ZIP_W			: Int = 2;		//ZIP without prediction
	private static inline var COMP_ZIP_P			: Int = 3;		//ZIP with prediction.
	
	private var fileData				: ByteArray;
	public var numChannels				: Int;
	public var canvas_height			: Int;
	public var canvas_width				: Int;
	public var colorChannelDepth		: Int;
	public var colorMode				: Int;
	public var colorModeStr				: String;
	public var allLayers				: Array<PSDLayer>; 	//array of all layer objects
	public var allBitmaps				: Array<PSDLayerBitmap>; 	//array of all bitmap objects
	public var composite_bmp			: BitmapData;
	
	//function new(blocker : Blocker, fromSingleton : Bool)
	//{
		//if (!fromSingleton || blocker == null) throw new Error("use getInstance");
	//}
	function new()
	{
		
	}
	
	public function parse(fileData:ByteArray):Void
	{
		this.fileData = fileData;
		
		readHeader();
		readImageResources();
		readLayerAndMaskInfo();
		readCompositeData();
	}

	private function readHeader() : Void 
	{
		//check signatue
		/*
			Signature: always equal to '8BPS'. Do not try to read the file if the
			signature does not match this value.
		 */
		var sig:String = fileData.readUTFBytes( 4 );
		if (sig!= "8BPS" ) throw ("invalid signature: " + sig );
		
		//version
		/*
		 * 	Version: always equal to 1. Do not try to read the file if the version does
			not match this value. (**PSB** version is 2.)
		 */
		var version: Int = fileData.readUnsignedShort();
		if (version!= 1) throw ("invalid version: " + version );
		
		//Reserved, must be zero
		fileData.position += 6;
		
		//chanels
		/*
			The number of channels in the image, including any alpha channels.
			Supported range is 1 to 56.
		 */
		numChannels = fileData.readUnsignedShort();
		
		//The height of the image in pixels. Supported range is 1 to 30,000.
		canvas_height = fileData.readInt();
		
		//The width of the image in pixels. Supported range is 1 to 30,000.
		canvas_width = fileData.readInt();
		
		//Depth: the number of bits per channel. Supported values are 1, 8, and 16.
		colorChannelDepth = fileData.readUnsignedShort();
		
		//document color mode
		/*		
			The color mode of the file. Supported values are: Bitmap = 0; Grayscale =
			1; Indexed = 2; RGB = 3; CMYK = 4; Multichannel = 7; Duotone = 8; Lab = 9. 
		*/
		colorMode = fileData.readUnsignedShort();

		switch (colorMode)
		{
			case 0 	: colorModeStr =  "BITMAP";//			break;
			case 1 	: colorModeStr =  "GRAYSCALE";//		break;
			case 2 	: colorModeStr =  "INDEXED";//		break;
			case 3 	: colorModeStr =  "RGB";//			break;
			case 4 	: colorModeStr =  "CMYK";//			break;
			case 7 	: colorModeStr =  "MULTICHANNEL";//	break;
			case 8 	: colorModeStr =  "DUOTONE";//		break;
			case 9 	: colorModeStr =  "LAB";//			break;
		}
		
		//color mode section
		/*
		 Only indexed color and duotone (see the mode field in Table 1.2) have color mode
		data. For all other modes, this section is just the 4-byte length field, which is set to zero. 
		 */
		var size:Int = fileData.readInt();
		fileData.position += size;
	
	}
	

	private function readImageResources():Void 
	{
		//Length of image resource section.
		var size:UInt = fileData.readUnsignedInt();
		
		// how much was read
		var read:UInt = 0;

		while ( read < size ) 
		{
			var sig:String = fileData.readUTFBytes(4); 
			if ( sig != "8BIM") throw ("Invalid signature: " + sig );
			read += 4;
			
			//Unique identifier for the resource.
			var resourceID:Int = fileData.readUnsignedShort();
			read += 2;
			
			//Name: Pascal string, padded to make the size even (a null name consists of two bytes of 0)
			var nameObj	= readPascalStringObj();
			var name	: String	= nameObj.str;
			read += nameObj.length;
			
			//Actual size of resource data that follows
			var resourceSize:UInt = fileData.readUnsignedInt();
			read += 4;
			
			//readResourceBlock(resourceSize, resourceID);
			fileData.position += resourceSize;
			read += resourceSize;
			
			if ( resourceSize % 2 == 1 ) {
				fileData.readByte();
				read++;
			}
		}
	}

	private function readLayerAndMaskInfo() : Void
	{
		//Length of the layer and mask information section.
		var size 	: UInt = fileData.readUnsignedInt();
		
		//current read position
		var pos 	: UInt = fileData.position;
		
		if ( size > 0 ) 
		{
			parseLayerInfo();
			parseMaskInfo();
			
			fileData.position += pos + size - fileData.position;
		}			
	}

	//loop throigh the layers and get all the layer info
	private function parseLayerInfo( ) : Void 
	{
		//Length of the layers info section, rounded up to a multiple of 2.
		var layerInfoSize 	: UInt = fileData.readUnsignedInt();
		
		//current read position
		var pos 			: Int = fileData.position;
		
		//all layers init
		allLayers = [];// new Array(numLayers);
		
		//all bitmaps init
		allBitmaps = [];// new Array(numLayers);
		
		if ( layerInfoSize > 0 ) 
		{
			//get total nu of layers
			var nLayers : Int = fileData.readShort();
			
			/*
				Layer count. If it is a negative number, its absolute value is the number of
				layers and the first alpha channel contains the transparency data for the
				merged result.				  
			 */
			var numLayers : Int = Std.int(Math.abs(nLayers));
			
			//loop through all layers to retrieve layer object info and image data
			for(i in 0...numLayers)
			{
				allLayers[i] = new PSDLayer(fileData);
			}
			
			for(i in 0...numLayers)
			{
				var layer_psd : PSDLayer = allLayers[i];
				var layer_bmp : PSDLayerBitmap = new PSDLayerBitmap(layer_psd, fileData); 
				allBitmaps[i] = layer_bmp;
				layer_psd.bmp = layer_bmp.image;
			}
		} 
		fileData.position += pos + layerInfoSize - fileData.position;
	}


	private function parseMaskInfo() : Void 
	{
		//TODO implement proper mask parsing
		var size 		: UInt = fileData.readUnsignedInt();
		var overlay 	: UInt = fileData.readUnsignedShort();
		var color1 		: UInt = fileData.readUnsignedInt();
		var color2 		: UInt = fileData.readUnsignedInt();
		var opacity 	: UInt = fileData.readUnsignedShort();
		var kind 		: UInt = fileData.readUnsignedByte();
		
		fileData.position += 1; // padding
	}		
	
	
	private function readCompositeData() :Void
	{
		//identify the compression
		var compression 		: Int 	= fileData.readUnsignedShort();
		//var channelsData_arr 	: Array = new Array();
		var channelsData_arr = [];
		
		switch (compression) 
		{
			case COMP_RAW: //get raw data
			
				for(channel in 0...numChannels)
				{
					var data:ByteArray = new ByteArray();
					fileData.readBytes( data, 0, canvas_width * canvas_height);
					channelsData_arr[channel] = data;
				}
				//break;
			
			case COMP_RLE:
				//var lines:Array = new Array( canvas_height * numChannels );
				var lines = [];
				var i:Int;
				
				for(i in 0...(canvas_height * numChannels))
				{
					lines[i] = fileData.readUnsignedShort();
				}
				
				for(channel in 0...numChannels)
				{
					var data = new ByteArray();
					
					var line:ByteArray = new ByteArray();
					for(i in 0...canvas_height)
					{
						line.length = 0;
						fileData.readBytes( line, 0, lines[channel * canvas_height + i] );
						unpack(line, data);
					}
					channelsData_arr[channel] = data;
				}				
				//break;
			
			default:
				throw ("invalid compression: " + compression );
				//break;
		}
		
		var r:ByteArray = channelsData_arr[0];
		var g:ByteArray = channelsData_arr[1];
		var b:ByteArray = channelsData_arr[2];
		r.position = 0;
		g.position = 0;
		b.position = 0;
		
		createCompositeBD(r, g, b);
	}
	
	
	function createCompositeBD(r:ByteArray, g:ByteArray, b:ByteArray):Void
	{
		//create composite bitmap out of byte array channels
		var wdt = canvas_width;
		var hgt = canvas_height;
		
		composite_bmp = new BitmapData( wdt, hgt, false, 0x000000 );
		
		for(y in 0...hgt)
		{
			for(x in 0...wdt)
			{
				composite_bmp.setPixel( x, y, r.readUnsignedByte() << 16 | g.readUnsignedByte() << 8 | b.readUnsignedByte() );
			}
		}
	}
	
	
	
	
	
	//unpack byte array data
	
	public function unpack( packed:ByteArray, imageData:ByteArray ):Void 
	{
		var i:Int;
		var n:Int;
		var byte:Int;
		var count:Int;
		
		while ( packed.bytesAvailable > 0 ) // ???
		{
			n = packed.readByte();
			
			if ( n >= 0 ) 
			{
				count = n + 1;
				
				packed.readBytes(imageData, imageData.position, count);
				imageData.position = imageData.position + count;
			} 
			else 
			{
				byte = packed.readByte();
				
				count = 1 - n;
				for(i in 0...count)
				{
					imageData.writeByte( byte );
				}
			}
		}
		
	}		

	
	
	
	
	
	
	
	//returns the read value and its length in format {str:value, length:size}
	private function readPascalStringObj(): { str:String, length:UInt }
	{
		var size:UInt = fileData.readUnsignedByte();
		size += 1 - size % 2;
		return  {str:fileData.readMultiByte( size, "shift-jis").toString(), length:size + 1};
	}
	
	public static function getInstance() : PSDParser 
	{ 
		if (instance == null) instance = new PSDParser();
		return instance;
	}				
}

