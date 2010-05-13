﻿package com.codeazur.as3swf
{
	import com.codeazur.as3swf.data.SWFRectangle;
	import com.codeazur.as3swf.tags.ITag;
	import com.codeazur.as3swf.timeline.Frame;
	import com.codeazur.as3swf.timeline.Scene;
	
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	
	public class SWF implements ITimeline
	{
		public var version:int = 10;
		public var fileLength:uint = 0;
		public var fileLengthCompressed:uint = 0;
		public var frameSize:SWFRectangle;
		public var frameRate:Number = 50;
		public var frameCount:uint = 1;
		
		public var compressed:Boolean;
		
		protected var _timeline:SWFTimeline;
		protected var _bytes:SWFData;
		
		public function SWF(ba:ByteArray = null) {
			_timeline = new SWFTimeline(this);
			_bytes = new SWFData();
			if (ba != null) {
				loadBytes(ba);
			} else {
				frameSize = new SWFRectangle();
			}
		}
		
		public function get timeline():SWFTimeline { return _timeline; }

		// Convenience getters
		public function get tags():Vector.<ITag> { return timeline.tags; }
		public function get dictionary():Dictionary { return timeline.dictionary; }
		public function get scenes():Vector.<Scene> { return timeline.scenes; }
		public function get frames():Vector.<Frame> { return timeline.frames; }
		public function get layers():Vector.<Array> { return timeline.layers; }
		
		// This shouldn't be public
		public function get bytes():SWFData { return _bytes; }
		
		public function getTagByCharacterId(characterId:uint):ITag {
			return timeline.getTagByCharacterId(characterId);
		}
		
		public function loadBytes(ba:ByteArray):void {
			bytes.length = 0;
			ba.position = 0;
			ba.readBytes(bytes);
			parseInternal();
		}
		
		public function parse(data:SWFData):void {
			_bytes = data;
			parseInternal();
		}
		
		protected function parseInternal():void {
			compressed = false;
			bytes.position = 0;
			var signatureByte:uint = bytes.readUI8();
			if (signatureByte == 0x43) {
				compressed = true;
			} else if (signatureByte != 0x46) {
				throw(new Error("Not a SWF. First signature byte is 0x" + signatureByte.toString(16) + " (expected: 0x43 or 0x46)"));
			}
			signatureByte = bytes.readUI8();
			if (signatureByte != 0x57) {
				throw(new Error("Not a SWF. Second signature byte is 0x" + signatureByte.toString(16) + " (expected: 0x57)"));
			}
			signatureByte = bytes.readUI8();
			if (signatureByte != 0x53) {
				throw(new Error("Not a SWF. Third signature byte is 0x" + signatureByte.toString(16) + " (expected: 0x53)"));
			}
			version = bytes.readUI8();
			fileLength = bytes.readUI32();
			fileLengthCompressed = bytes.length;
			if (compressed) {
				// The following data (up to end of file) is compressed, if header has CWS signature
				bytes.swfUncompress();
			}
			frameSize = bytes.readRECT();
			frameRate = bytes.readFIXED8();
			frameCount = bytes.readUI16();
			timeline.parse(bytes, version);
		}
		
		public function publish(ba:ByteArray):void {
			var data:SWFData = new SWFData();
			data.writeUI8(compressed ? 0x43 : 0x46);
			data.writeUI8(0x57);
			data.writeUI8(0x53);
			data.writeUI8(version);
			var fileLengthPos:uint = data.position;
			data.writeUI32(0);
			data.writeRECT(frameSize);
			data.writeFIXED8(frameRate);
			data.writeUI16(frameCount); // TODO: get the real number of frames from the tags
			timeline.publish(data, version);
			fileLength = fileLengthCompressed = data.length;
			if (compressed) {
				data.position = 8;
				data.swfCompress();
				fileLengthCompressed = data.length;
			}
			var endPos:uint = data.position;
			data.position = fileLengthPos;
			data.writeUI32(fileLength);
			data.position = 0;
			ba.length = 0;
			ba.writeBytes(data);
		}
		
		public function toString():String {
			return "[SWF]\n" +
				"  Header:\n" +
				"    Version: " + version + "\n" +
				"    FileLength: " + fileLength + "\n" +
				"    FileLengthCompressed: " + fileLengthCompressed + "\n" +
				"    FrameSize: " + frameSize.toStringSize() + "\n" +
				"    FrameRate: " + frameRate + "\n" +
				"    FrameCount: " + frameCount +
				timeline.toString();
		}
	}
}
