package com.durej.psdparser;

/**
 * tree node (folder/child)
 * @author ryzed
 */
class PSDStructureNode
{
	public var layer:PSDLayer;
	public var childs:Array<PSDStructureNode>;
	
	public function new(layer:PSDLayer)
	{
		this.layer = layer;
		this.childs = [];
	}
	
	inline public function numChildren():Int
	{
		return childs.length;
	}
	
	inline public function addChild(child:PSDStructureNode):Void
	{
		childs.push(child);
	}
	
	inline public function isGroup():Bool
	{
		return (layer == null) ? true : (layer.type == PSDLayer.LayerType_FOLDER_OPEN || layer.type == PSDLayer.LayerType_FOLDER_CLOSED);
	}
	inline public function isEndGroup():Bool
	{
		return (layer == null) ? false : (layer.type == PSDLayer.LayerType_HIDDEN);
	}
	inline public function isNormal():Bool
	{
		return (layer == null) ? false : (layer.type == PSDLayer.LayerType_NORMAL);
	}
	
}