package ;

import com.durej.psdparser.PSDChannelInfoVO;
import com.durej.psdparser.PSDLayer;
import com.durej.psdparser.PSDLayerBitmap;
import com.durej.psdparser.PSDParser;
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.Sprite;
import flash.display.StageAlign;
import flash.display.StageScaleMode;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.Lib;
#if flash
import flash.net.FileFilter;
import flash.net.FileReference;
#end
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.text.TextFormat;
import openfl.Assets;

/**
 * ...
 * @author ryzed
 */

class Main extends Sprite
{
	#if flash
	private var file					: FileReference;
	#end
	private var psdParser				: PSDParser;
	private var layersLevel				: Sprite;
	
	static function main() 
	{
		var stage = Lib.current.stage;
		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.align = StageAlign.TOP_LEFT;
		// entry point
		
		var m = new Main();
		stage.addChild(m);
	}

	public function new()
	{
		super();
		addEventListener(Event.ADDED_TO_STAGE, init);
	}
	
	
	private function init(e:Event)
	{
		#if flash
		var wid = Lib.current.stage.stageWidth;
		var hei = Lib.current.stage.stageHeight;
		
		//draw shape and add it to sprite so that stage is clickable
		var bg:Sprite = new Sprite();
		bg.graphics.beginFill(0x3d4d5d);
		bg.graphics.drawRect(0, 0, wid, hei);
		this.addChild(bg);
		
		//add text prompt
		var format:TextFormat 		= new TextFormat();
		format.bold					= true;
		format.font					= "Arial";
		format.color				= 0xDEDEDE;
		format.size					= 28;
		
		var prompt_txt:TextField 	= new TextField();
		prompt_txt.width			= 600;
		prompt_txt.autoSize			= TextFieldAutoSize.LEFT;
		prompt_txt.multiline 		= true;
		prompt_txt.wordWrap 		= true;
		prompt_txt.selectable 		= false;			
		
		prompt_txt.text 			= "CLICK ANYWHERE TO LOAD PSD FILE \nAfter file has been loaded click anywhere to cycle through layers";
		
		prompt_txt.setTextFormat(format);
		
		this.addChild(prompt_txt);
			
		prompt_txt.x				= (wid/2 - prompt_txt.width/2 );
		prompt_txt.y 				= (hei/2 - prompt_txt.height/2);
		
		//init stage
		this.stage.align 			= StageAlign.TOP_LEFT;
		this.stage.scaleMode 		= StageScaleMode.NO_SCALE;
		
		//click callback
		this.addEventListener(MouseEvent.CLICK, loadPSD);
		#else
		parsePSDData(null);
		#end
	}
	
	#if flash
	//load action must be perfomed on click due to the flash 10 security
	function loadPSD(e:Event):Void
	{
		file = null;
		file = new FileReference();
		file.addEventListener(Event.SELECT, onFileSelected);
		file.browse([new FileFilter("Photoshop Files","*.psd;")]); 
	}
	
	//after file has been selected , load it
	function onFileSelected(event:Event):Void 
	{
		file.removeEventListener(Event.SELECT, onFileSelected);
		file.addEventListener(Event.COMPLETE,parsePSDData);
		file.load();
	}
	#end
	
	//after file has been loaded parse it	
	function parsePSDData(event:Event):Void
	{
		psdParser = PSDParser.getInstance();
		
		#if flash
		psdParser.parse(file.data);	
		#else
		var data = Assets.getBytes("assets/testPSD1.psd");
		psdParser.parse(data);
		#end
		
		layersLevel = new Sprite();
		this.addChild(layersLevel);
		
		for (i in 0...psdParser.allLayers.length)
		{
			var psdLayer 		: PSDLayer			= psdParser.allLayers[i];
			var layerBitmap_bmp : BitmapData 		= psdLayer.bmp;
			var layerBitmap 	: Bitmap 			= new Bitmap(layerBitmap_bmp);
			layerBitmap.x 							= psdLayer.position.x;
			layerBitmap.y 							= psdLayer.position.y;
			layerBitmap.filters						= psdLayer.filters_arr;
			layersLevel.addChild(layerBitmap);
		}
		
		//var compositeBitmap:Bitmap = new Bitmap(psdParser.composite_bmp);
		//layersLevel.addChild(compositeBitmap);
		#if flash
		this.removeEventListener(MouseEvent.CLICK, loadPSD);
		#end
		this.addEventListener(MouseEvent.CLICK, shuffleBitmaps);
	}	

	private function shuffleBitmaps(event : MouseEvent) : Void 
	{
		layersLevel.setChildIndex(layersLevel.getChildAt(0), layersLevel.numChildren-1);
	}
}