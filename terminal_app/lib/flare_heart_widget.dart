import "dart:typed_data";

import "package:flare/flare.dart" as flr;
import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";

class FlareHeart extends LeafRenderObjectWidget
{
	final String src;
	final bool isDead;
	final bool isSmall;
	final double opacity;

	FlareHeart(
		this.src,
		this.isDead,
		{
			Key key,
			this.opacity,
            bool isSmall
		}): isSmall = isSmall ?? false, super(key: key);

	@override
	RenderObject createRenderObject(BuildContext context) 
	{
		return new HeartRenderObject(src, isDead, isSmall);
	}

	@override
	void updateRenderObject(BuildContext context, covariant HeartRenderObject renderObject)
	{
		renderObject..src = src
					..isDead = isDead
					..opacity = opacity;
	}
}

class HeartRenderObject extends RenderBox
{
	String _src;
	flr.FlutterActor _actor;
	Float32List _aabb;
	bool _isDead;
	double _opacity;
	flr.ActorAnimation _animation;
	double _animationTime = 0.0;
	double _lastFrameTime = 0.0;

	HeartRenderObject(String src, bool isDead, bool isSmall)
	{
		this.src = src;
		this.isDead = isDead;
	}

	void beginFrame(Duration timeStamp) 
	{
		if(_animation == null)
		{
			return;
		}
		final double t = timeStamp.inMicroseconds / Duration.microsecondsPerMillisecond / 1000.0;
		
		if(_lastFrameTime == 0)
		{
			_lastFrameTime = t;
			SchedulerBinding.instance.scheduleFrameCallback(beginFrame);
			// hack to circumvent not being enable to initialize lastFrameTime to a starting timeStamp (maybe it's just the date?)
			// Is the FrameCallback supposed to pass elapsed time since last frame? timeStamp seems to behave more like a date
			return;
		}
		
		double elapsed = (t - _lastFrameTime).clamp(0.0, 1.0);
		_lastFrameTime = t;

		_animationTime = (_animationTime + (isDead ? elapsed : -elapsed)).clamp(0.0, _animation.duration);
		_animation.apply(_animationTime, _actor, 1.0);
		_actor.advance(elapsed);
	
		if((isDead && _animationTime < _animation.duration) || (!isDead && _animationTime > 0.0))
		{
			SchedulerBinding.instance.scheduleFrameCallback(beginFrame);
		}
		markNeedsPaint();
	}

	@override
	bool get sizedByParent => false;
	
	@override
	bool hitTestSelf(Offset screenOffset) => true;

	@override
	void performLayout()
	{
		if(_actor != null)
		{
			_actor.root.opacity = _opacity;
			_actor.advance(0.0);
			_aabb = _actor.computeAABB();
			size = new Size(_aabb[2] - _aabb[0], _aabb[3] - _aabb[1]);
		}
		else
		{
			size = new Size(1.0, 1.0);
		}
	}
	
	@override
	void paint(PaintingContext context, Offset offset)
	{
		final Canvas canvas = context.canvas;
		
		if(_actor != null && _opacity > 0.0)
		{
			canvas.save();
			canvas.translate(offset.dx, offset.dy);
			_actor.draw(canvas);
			canvas.restore();
		}		
	}

	set opacity(double value)
	{
		if(value == _opacity)
		{
			return;
		}
		_opacity = value;
		markNeedsLayout();
	}

	bool get isDead
	{
		return _isDead;
	}

	set isDead(bool d)
	{
		if(_isDead == d)
		{
			return;
		}
		_isDead = d;
		_lastFrameTime = 0.0;
		SchedulerBinding.instance.scheduleFrameCallback(beginFrame);
	}

	String get src
	{
		return _src;
	}

	set src(String value)
	{
		if(_src == value)
		{
			return;
		}
		_src = value;

		if(value == null)
		{
			markNeedsPaint();
			return;
		}
		flr.FlutterActor actor = new flr.FlutterActor();
		actor.loadFromBundle(value).then(
			(bool success)
			{
				_actor = actor;
				_animation = _actor.getAnimation("Dead Monitor");
				_animationTime = 0.0;
				// Heart on the terminal app should be smaller
				_actor.root.scaleX = 0.5;
				_actor.root.scaleY = 0.5;
				markNeedsLayout();
				markNeedsPaint();
				SchedulerBinding.instance.scheduleFrameCallback(beginFrame);
			}
		);
	}
}
