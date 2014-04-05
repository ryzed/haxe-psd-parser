package com.durej.psdparser;

import flash.geom.Rectangle;
import flash.display.BitmapData;
import flash.utils.ByteArray;
/**
 * @author Slavomir Durej
 */


class PSDLayerBitmap 
{
	static inline var A = 0;
	static inline var R = 1;
	static inline var G = 2;
	static inline var B = 3;
	
	
	private var layer 			: PSDLayer;
	private var fileData 		: ByteArray;
	private var lineLengths 	: Array<UInt>;

	public var channels 		: Array<ByteArray>;
	public var image 			: BitmapData;
	private var width 			: Int;
	private var height 			: Int;

	
	public function new ( layer:PSDLayer, fileData:ByteArray) 
	{
		this.layer 				= layer;
		this.fileData 			= fileData;

		readChannels();
	}
	
	private function readChannels():Void
	{
		//init image channels
		channels		= [];
		channels[A] 	= new ByteArray();
		channels[R] 	= new ByteArray();
		channels[G] 	= new ByteArray();
		channels[B] 	= new ByteArray();
		
		var channelsLength = layer.channelsInfo_arr.length;
		
		var isTransparent = (channelsLength > 3);
		
		if (layer.type != PSDLayer.LayerType_NORMAL)
		{
			var pixelDataSize:Int = 0;
			
			for(i in 0...channelsLength)
			{
				var channelLenghtInfo	:PSDChannelInfoVO = layer.channelsInfo_arr[i];
				pixelDataSize += channelLenghtInfo.length;
			}
			//skip image data parsing for layer folders (for now)
			fileData.position+= pixelDataSize;
			return;
		}

		for(i in 0...channelsLength)
		{
			var channelLenghtInfo	 		= layer.channelsInfo_arr[i];
			var channelID					= channelLenghtInfo.id;
			var channelLength		 		= channelLenghtInfo.length;
			
			//determine the correct width and height
			if (channelID < -1) 
			{
				//use the mask dimensions
				width 	= Std.int(layer.maskBounds.width);
				height 	= Std.int(layer.maskBounds.height);
			}
			else
			{
				//use the layer dimensions
				width 	= Std.int(layer.bounds.width);
				height 	= Std.int(layer.bounds.height);
			}
			
			
			if ((width*height) == 0) //TODO fix this later
			{
				var compression = fileData.readShort();
				return;
			}
			
			var channelData:ByteArray = readColorPlane(i,height,width, channelLength);
			
			if (channelData.length == 0) return; //TODO fix this later				

			if (channelID == -1)
			{
				channels[A] = channelData; 
				//TODO implement [int(ch * opacity_devider) for ch in channel] ; from pascal
			}
			else if (channelID == 0)
			{
				channels[R] 	= channelData;
			}
			else if (channelID == 1)
			{
				channels[G] 	= channelData;
			}
			else if (channelID == 2)
			{
				channels[B] 	= channelData;
			}
			else if (channelID < -1)
			{
				channels[A] = channelData;
				//TODO implement : [int(a * (c/255)) for a, c in zip(self.channels["a"], channel)] from pascal
			}
		}
		
		renderImage(isTransparent);
	}

	private function readColorPlane(planeNum:Int, height:Int, width:Int, channelLength:Int):ByteArray
	{
		var channelDataSize = width * height;
		var isRLEncoded = false;
		var imageData:ByteArray;
		var i;

		imageData = new ByteArray();
		
		var compression = fileData.readShort();
		isRLEncoded = (compression == 1);
		
		if (isRLEncoded)
		{
			lineLengths = [];// new Array(height);
			
			for(i in 0...height)
			{
				lineLengths[i] = fileData.readUnsignedShort();
			}
			//read compressed chanel data 
			for(i in 0...height)
			{
				var line:ByteArray = new ByteArray();
				fileData.readBytes( line, 0, lineLengths[i] );
				imageData.writeBytes( unpack( line ) );
			}
		}
		else
		{
			if (compression == 0)
			{
				//read raw data
				fileData.readBytes( imageData, 0,  channelDataSize);
			}
			else
			{
				//skip data
				fileData.position+=channelLength;
			}
		}

		return imageData;	
	}



	
	private function renderImage( transparent:Bool = false ):Void 
	{
		if (transparent) image = new BitmapData( width, height, true, 0x00000000 );
		else image = new BitmapData( width, height, false, 0x000000 );
		
		var a:ByteArray = null;
		var r:ByteArray = null;
		var g:ByteArray = null;
		var b:ByteArray = null;
		
		//init alpha channel
		if (transparent)
		{
			a = channels[A];
			a.position = 0;
		}
		
		var onlyTransparent:Bool = (channels[R].length == 0 && channels[G].length == 0 && channels[B].length == 0);
		
		if (!onlyTransparent)
		{
			//init channels
			r = channels[R];
			g = channels[G];
			b = channels[B];
			
			//reset position
			r.position = 0;
			g.position = 0;
			b.position = 0;
		}

		//var color:UInt;
		
		for(y in 0...height)
		{
			for(x in 0...width)
			{
				if (onlyTransparent)
				{
					var color = a.readUnsignedByte();
					image.setPixel32( x, y, color);
				}
				else
				{
					if (transparent)
					{
						var color = a.readUnsignedByte() << 24 | r.readUnsignedByte() << 16 | g.readUnsignedByte() << 8 | b.readUnsignedByte();
						image.setPixel32( x, y, color);
					}
					else
					{
						var color = r.readUnsignedByte() << 16 | g.readUnsignedByte() << 8 | b.readUnsignedByte();	
						image.setPixel( x, y, color );
					}
				}
			}
		}
	}
	
	
	
	public function unpack( packed:ByteArray ):ByteArray 
	{
		var i:Int;
		var n:Int;
		var byte:Int;
		var unpacked:ByteArray = new ByteArray();
		var count:Int;
		
		while ( packed.bytesAvailable > 0 ) // ???
		{
			n = packed.readByte();
			
			if ( n >= 0 ) 
			{
				count = n + 1;
				for(i in 0...count)
				{
					unpacked.writeByte( packed.readByte() );
				}
			} 
			else 
			{
				byte = packed.readByte();
				
				count = 1 - n;
				for(i in 0...count)
				{
					unpacked.writeByte( byte );
				}
			}
		}
		
		return unpacked;
	}		
}
