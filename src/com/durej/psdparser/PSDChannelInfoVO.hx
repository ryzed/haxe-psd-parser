package com.durej.psdparser;

import flash.utils.ByteArray;
/**
 * @author Slavomir Durej
 */
class PSDChannelInfoVO 
{
	public var id : Int;
	public var length : UInt;

	public function new(fileData : ByteArray) 
	{
		id 		= fileData.readShort();
		length 	= fileData.readUnsignedInt();			
	}
}
