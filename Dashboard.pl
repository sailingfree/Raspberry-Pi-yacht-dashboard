#!/usr/bin/perl
# Dashboard for raspberry pi and a 7 inch touch screen
use Graphics::Framebuffer;

use Data::Dumper;

use LWP::UserAgent;

use JSON;

use Scalar::Util qw(looks_like_number);

use Date::Parse;

use RRDTool::OO;

our $RUNNING = 1;
sub sighan {
	$RUNNING = 0; 
	print STDOUT "Quitting.\n";
	exit;
}
our $fb = Graphics::Framebuffer->new('SPLASH'=>0,'SHOW_ERRORS'=>1, 'ACCELERATED'=>1, 'RESET'=>0);
#$fb->cls('OFF'); # Clear screen and turn off the console cursor
$SIG{'QUIT'} = \&sighan;
$SIG{'INT'} = \&sighan;
$SIG{'HUP'} = \&sighan;
$SIG{'TERM'} = \&sighan;

my $xres = $fb->{'XRES'};
my $yres = $fb->{'YRES'};
my @background = {'red' => 160, 'green' => 160, 'blue' => 160, 'alpha' => 255};
my @black = {'red' => 0, 'green' => 0, 'blue' => 0, 'alpha' => 255};
my @box_color = {'red' => 255, 'green' => 0, 'blue' => 0, 'alpha' => 255};
my @gauge_color = {'red' => 200, 'green' => 200, 'blue' => 200, 'alpha' => 255};


# Create the main background and fill it.§
#
#
sub drawBackground {
	$fb->normal_mode();
	$fb->set_color(@background);
	$fb->box({'x'=>0, 'y'=>0, 'xx'=>$xres, 'yy'=>$yres, 'radius'=>0,'filled'=>1});
}


# Paths for the font we want.
my $path = '/usr/share/fonts/truetype/liberation2';
my $face = 'LiberationSans-Bold.ttf';

$path = '/usr/share/fonts/truetype/quicksand';
$face = 'Quicksand-Medium.ttf';

my $sog,$wspeed, $wangle, $d, $hdg, $dateTimeDisp, $temp, $press, $windy, $houseBatt, $engineBat, $net;


sub createInstruments {
	$sog = Numeric->new('SOG', 0, 0, $xres/3 ,$yres/3,'SOG (kts)');
	$wspeed = Numeric->new('TWS', $xres/3, 0, $xres/3 ,$yres/3,'Wind (A kts)');
	$wangle = Numeric->new('TWA', 2* $xres/3, 0, $xres/3 ,$yres/3,'Wind Angle (A)');
	$d = Numeric->new('DPT', 0, $yres/3, $xres/3 ,$yres/3,'Depth (m)');
	$hdg = Numeric->new('HDG', $xres/3, $yres/3, $xres/3 ,$yres/3,'Heading');
	$dateTimeDisp = Numeric->new('DATE', 0, 2*$yres/3, $xres/3, $yres/6, 'Date/Time'); 
	$temp = Numeric->new('TMP', 0, 5*$yres/6, $xres/6, $yres/6,'Temp (C)');
	$press = Numeric->new('PRESS', $xres/6, 5*$yres/6, $xres/6, $yres/6,'Press (Pa)');

	$windy = Dial->new(2*$xres/3, $yres/3, $xres/3, 2*$yres/3, "");
	$houseBatt = Numeric->new('BAT1', 2*$xres/6, 2*$yres/3, $xres/6, $yres/6, "House V");
	$engineBatt = Numeric->new('BAT2', 3*$xres/6, 2*$yres/3, $xres/6, $yres/6, "Engine V");
	$net = Numeric->new('NET', 2*$xres/6, 5*$yres/6, $xres/3, $yres/6, 'Network');
}
# Create the instruments to display
drawBackground();
createInstruments();

# Main look to read the signal k source parse the result and display
#

# Main loop to read the signal k source parse the result and display
# the instruments
sub signalk_handler {
	do {
		my $ua = LWP::UserAgent->new;
		my $url = 'http://localhost:3000/signalk/v1/api/';
		my $req = HTTP::Request->new(GET=>$url);
		$req->header('content-type'=>'application/json');
		my $resp = $ua->request($req);
		my $msg = $resp->decoded_content;
		my $sc = decode_json($msg);
		$Data::Dumper::Indent = 1;
		my $urn = $sc->{'self'};
		$urn =~ s/vessels\.//;
#		print STDOUT Dumper($sc);

		my $temperatureOutside = $sc->{'vessels'}->{$urn}->{'environment'}->{'outside'}->{'temperature'}->{'value'};
		my $pressureOutside = $sc->{'vessels'}->{$urn}->{'environment'}->{'outside'}->{'pressure'}->{'value'};
		my $depth = $sc->{'vessels'}->{$urn}->{'environment'}->{'depth'}->{'belowTransducer'}->{'value'};

		my $wind = $sc->{'vessels'}->{$urn}->{'environment'}->{'wind'}->{'speedApparent'}->{'value'};
		my $windangle = $sc->{'vessels'}->{$urn}->{'environment'}->{'wind'}->{'angleApparent'}->{'value'};
		my $speedoverground = $sc->{'vessels'}->{$urn}->{'navigation'}->{'speedOverGround'}->{'value'};
		my $headingTrue = $sc->{'vessels'}->{$urn}->{'navigation'}->{'headingTrue'}->{'value'};
		my $dateTime = $sc->{'vessels'}->{$urn}->{'navigation'}->{'headingTrue'}->{'timestamp'};

		my $essid = `/usr/sbin/iwconfig 2>&1|grep wlan|sed "s/:/ /" | awk '{print \$5}'`;
		chomp($essid);
		$d->updateFloat($depth, 1);
		$wspeed->updateFloat($wind, 1.97);	
		$wangle->updateAngle($windangle);
		$sog->updateFloat($speedoverground, 1.97);	## Convert m/s to knots
		$hdg->updateAngle($headingTrue);
		my($ss,$mm,$hh,$day,$month,$year,$zone) = strptime($dateTime);
		$dateTimeDisp->updateText("$hh:$mm:" . int($ss));
		$windy->update($windangle * 57.29);
		$temp->update($temperatureOutside);
		$press->updateFloat($pressureOutside, 0.01);
		$houseBatt->updateFloat(12.12,1);
		$engineBatt->updateFloat(13.92,1);
		$net->update($essid);
		sleep(1);

		# Load the image
		#my $img = $fb->load_image({'file'=>"rrd/DPT.png", 
		#		'center'=>CENTER_XY});

		# Copy the area to be drawn over
		#$old = $fb->blit_read({'x'=>$img->{'x'}, 
		#		'y'=>$img->{'y'},
		#		'width'=>$img->{'width'}, 
		#		'height'=>$img->{'height'}});
##
		#$fb->blit_write($img);
		#sleep(1);
		#$fb->blit_write($old);

	} while(1);
}
signalk_handler();


print STDOUT "All done\n";
print STDOUT "Done\n";


{
	package Numeric;

	use Data::Dumper;
	use Scalar::Util qw(looks_like_number);

	sub new {
		my $class = shift;
		my $x;
		my $self = {
			'name' => shift,
			'x' => shift,
			'y' => shift,
			'width' => shift,
			'height' =>shift,
			'label' => shift,
			'value' => shift,
			'lastValue' => '',
			'decimals' => 1, 
			'filter' => 4
		};

		bless $self, $class;

		# Draw the outline of the box
		$fb->set_color(@box_color);
		$fb->rbox({'x'=>$self->{'x'}, 'y'=>$self->{'y'}, 'width'=>$self->{'width'}, 'height'=>$self->{'height'}, 'radius'=>0,'filled'=>0,'pixel_size'=>2});

		my $x=$self->{'x'};
		my $y = $self->{'y'};
		my $w=$self->{'width'};
		my $h=$self->{'height'};
		my $bb = $fb->ttf_print({'x'=>0,
				'y'=>$y + 60,
				'height'=>$h/5,
				'wscale' => 1,
				'color'=>'00000000',
				'text'=>$self->{'label'},
				'font_path'=>$path,
				'face'=>$face,
				'bb' => TRUE,
				'center' => CENTER_X,
				'antialias' => TRUE});

		# Now we have the bounding box center the label at the 
		# top of the box
		# and set the alpha to ff
		# Fudge the pheight as its a bit too big
		$bb->{'pheight'} *= 0.8;
		$bb->{'x'} = $x + ($w /2) - ($bb->{'pwidth'} / 2);
		$bb->{'y'} = $y + ($bb->{'pheight'});
		$bb->{'color'} = '000000FF';


		my $bb = $fb->ttf_print($bb);

		mkdir 'rrd';
		my $rrd = RRDTool::OO->new(
			file => 'rrd/' . $self->{'name'} . "_rrd.rrd" );

		# Create a round-robin database
		my $rows = 5;    # 
		$rrd->create(
			step        => 10,  # intervals
			data_source => { name => $self->{'name'} . "_data",
			type      => "GAUGE",
	       		min =>0	},
			archive     => { rows      => 60 });

		$self->{'rrd'} = $rrd;

		$self->{'lastrrd'} = time;

		return $self;
	}
	sub updateFloat {
		my $self = shift;
		my $value = shift;	
		my $multiplier = shift;

		if(looks_like_number($value)) {
			$decimals = $self->{'decimals'};
			$fmt = "%." . $decimals . "f";
			# Low pass filter to smooth the values out over time
			$filter = $self->{'filter'};
			$fvalue = (($self->{'value'} * ($filter - 1) ) + $value) /$filter ;
			$self->{'value'} = $fvalue;
			$self->update(sprintf($fmt, $fvalue * $multiplier));
			$self->updateRRD($value * $multiplier);
		} else {
			$self->update("--.--");
		}
	}

	sub updateAngle {
		my $self = shift;
		my $value = shift;
		if(looks_like_number($value)) {
			$self->update(int($value * 57.29) . ' ');
			$self->updateRRD(int($value * 57.29));
		} else {
			$self->update("---");
		}
	}

	sub updateText {
		my $self = shift;
		my $value = shift;
		if(!defined($value) || $value == "") {
			$self->update('------');
		} else { 
			$self->{'lastValue'} = '';  
			$self->update($value);
		}		
	}

	sub updateRRD {
		my $self = shift;
		my $value = shift;

		my $rrd = $self->{'rrd'};
		if(time - $self->{'lastrrd'} >= 10) {
			$rrd->update($value);
			$rrd->graph(image => "rrd/" . $self->{'name'} . ".png",
				vertical_label => $self->{'name'},
				start => time() - 600,
				draw => { thickness => 2,
					type => "line",
					color => '0000FF',
					legend => $self->{'label'},
				},
			);		
			$self->{'lastrrd'} = time;

			my $r = $rrd->fetch_start();
			$rrd->fetch_skip_undef();
	#		while(my($time,$value) = $rrd->fetch_next()) {
		#		if(defined $value) {
			#		print STDOUT "$time: $value\n";
				#}
		#	}
		}
	}

	sub update {
		my $self = shift;
		my $value = shift;	
		my $oldbb = $self->{'oldbb'};
		my $x=$self->{'x'};
		my $y = $self->{'y'};
		my $w=$self->{'width'};
		my $h=$self->{'height'};


		if($value ne $self->{'lastValue'}) {
			$fb->normal_mode();
			# Blank the old value using the old bounding box
			if($oldbb) {
				$fb->set_color(@background);
				# Fudge the pheight as its a bit too big
				$oldbb->{'pheight'} *= 0.9;
				$fb->rbox({'x'=>$oldbb->{'x'},
						'y'=>$oldbb->{'y'} - $oldbb->{'pheight'}, 
						'width'=>$oldbb->{'pwidth'}, 
						'height'=>$oldbb->{'pheight'}, 
						'radius'=>0,
						'filled'=>1});
				$fb->set_color(@background);
			}
			my $bb = $fb->ttf_print(
				{'x'=>$x,
					'y'=>$y + $h,
					'height'=>$h/2.5,
					'wscale' => 1.0,
					'color'=>'00000000',
					'text'=>$value,
					'font_path'=>$path,
					'face'=>$face,
					'bounding_box' => TRUE,
					'center' => CENTER_X,
					'antialias' => TRUE});

			# Now we've got the bounding box 
			# Center the text in the middle of the bottom half
			$bb->{'x'} = $x + ($w / 2) - ($bb->{'pwidth'} /2 );
			$bb->{'y'} -= 2;  # Adjust to it misses the boundary

			$fb->set_color(@background);

			# Save the current bb for next time
			$self->{'oldbb'} = $bb;

			# Print the bounding box with the new width 
			$bb->{'color'} = '000000FF';
			$fb->ttf_print($bb);

			$self->{'lastValue'} = $value;

		}
	}
}

{
	package Dial;

	use Data::Dumper;
	use Math::Trig;
	use parent -norequire, 'Numeric';

	sub min ($$) { $_[$_[0] > $_[1]] }
	sub max ($$) { $_[$_[0] < $_[1]] }

	sub copyRect {
		my $self = shift;
		my $x = shift;
		my $y = shift;
		my $w = shift;
		my $h = shift;
		my @mem;
		my $idx = 0;

		for(my $row = 0; $row < $h; $row++) {
			for(my $col = 0; $col < $w; $col++) {
				$mem[$idx] = $fb->pixel({'x'=>$col + $x, 'y'=>$row + $y});
				$idx++;
			}
		}
		return @mem;
	}

	sub drawRect {
		my $self = shift;
		my $x = shift;
		my $y = shift;
		my $w = shift;
		my $h = shift;

		my $mem = shift;
		my $idx = 0;

		for(my $row = 0; $row < $h; $row++) {
			for(my $col = 0; $col < $w; $col++) {
				my $red = $mem->[$idx]->{'red'};
				my $green = $mem->[$idx]->{'green'};
				my $blue = $mem->[$idx]->{'blue'};
				my $alpha = $mem->[$idx]->{'alpha'};
				$fb->set_color({'red' => $red, 'green' => $green, 'blue' => $blue, 'alpha' => $alpha});
				$fb->plot({'x'=>$col + $x, 'y'=>$row + $y,'pixel_size'=>1});
				$idx++
			}
		}
	}
	sub new {
		my $class = shift;
		my $x;
		my $self = {
			'x' => shift,
			'y' => shift,
			'width' => shift,
			'height' =>shift,
			'label' => shift,
			'value' => shift
		};

		bless $self, $class;
		$fb->set_color(@bax_color);
		$fb->rbox({'x'=>$self->{'x'}, 'y'=>$self->{'y'}, 'width'=>$self->{'width'}, 'height'=>$self->{'height'}, 'radius'=>4,'filled'=>0,'pixel_size'=>1});

		my $x=$self->{'x'};
		my $y = $self->{'y'};
		my $w=$self->{'width'};
		my $h=$self->{'height'};
		my $bb = $fb->ttf_print({'x'=>0,
				'y'=>$y + 60,
				'height'=>$h/5,
				'wscale' => 1,
				'color'=>'00000000',
				'text'=>$self->{'label'},
				'font_path'=>$path,
				'face'=>$face,
				'bb' => TRUE,
				'center' => CENTER_X,
				'antialias' => TRUE});

		# Now we have the bounding box center the label at the 
		# top of the box
		# and set the alpha to ff
		# Fudge the pheight as its a bit too big
		$bb->{'pheight'} *= 0.8;
		$bb->{'x'} = $x + ($w /2) - ($bb->{'pwidth'} / 2);
		$bb->{'y'} = $y + ($bb->{'pheight'});
		$bb->{'color'} = '000000FF';


		my $bb = $fb->ttf_print($bb);

		sub drawMajorTick {
			my $self = shift;
			my $major = shift;
			my $radius = shift;
			my $x=$self->{'x'};
			my $y = $self->{'y'};
			my $w=$self->{'width'};
			my $h=$self->{'height'};
			my $centrex = $x + ($w/2);
			my $centrey = $y + ($h/2);
			$fb->set_color(@black);
			my $length = 15;
			my $angle = deg2rad($major);
			my $x = $centrex + (sin($angle) * ($radius - $length));
			my $y = $centrey + (cos($angle) * ($radius - $length));
			my $xx = $centrex + (sin($angle) * ($radius - 1));
			my $yy = $centrey + (cos($angle) * ($radius - 1));
			$fb->line({'x'=>$x, 'y'=>$y, 'xx'=>$xx, 'yy'=>$yy, 'pixel_size'=>3});
		}

		sub drawMajors {
		my $radius = min($w*0.8, $h*0.9) / 2;
			for(my $major = 0; $major < 12; $major ++) {
				$self->drawMajorTick($major * 30, $radius);
			}
		}

		sub drawMinors {
			$self = shift;
			my $x=$self->{'x'};
			my $y = $self->{'y'};
			my $w=$self->{'width'};
			my $h=$self->{'height'};
			my $centrex = $x + ($w/2);
			my $centrey = $y + ($h/2);
			$fb->set_color(@black);
			my $radius = min($w*0.8, $h*0.9) / 2;
			for(my $major = 0; $major < 36; $major ++) {
				my $length = 10;
				my $angle = deg2rad($major * 10);
				my $x = $centrex + (sin($angle) * ($radius - $length));
				my $y = $centrey + (cos($angle) * ($radius - $length));
				my $xx = $centrex + (sin($angle) * ($radius - 1));
				my $yy = $centrey + (cos($angle) * ($radius - 1));
				$fb->line({'x'=>$x, 'y'=>$y, 'xx'=>$xx, 'yy'=>$yy, 'pixel_size'=>1});
			}
		}

		sub drawNumbers {
			$self = shift;
			my $x=$self->{'x'};
			my $y = $self->{'y'};
			my $w=$self->{'width'};
			my $h=$self->{'height'};
			my $centrex = $x + ($w/2);
			my $centrey = $y + ($h/2);
			$fb->set_color(@black);
			my $radius = min($w*0.8, $h*0.9) / 2;
		for(my $major = 0; $major < 12; $major ++) {
			my $inset = 30;
			my $angle = deg2rad($major * 30);
			my $x = $centrex + (sin($angle) * ($radius - $inset));
			my $y = $centrey - (cos($angle) * ($radius - $inset));
			my $xx = $centrex + (sin($angle) * ($radius - 1));
			my $yy = $centrey - (cos($angle) * ($radius - 1));
			my $bb = $fb->ttf_print({'x'=>$x,
					'y'=>$y,
					'height'=>20,
					'wscale' => 1,
					'color'=>'00000000',
					'text'=> $major * 30 . ' ',
					'font_path'=>$path,
					'face'=>$face,
					'bb' => TRUE,
					'center' => CENTER_X,
					'antialias' => TRUE});

			# Now we have the bounding box center the numbers at the 
			# center of the pointon the dial
			# and set the alpha to ff
			# Fudge the pheight as its a bit too big
			$bb->{'color'} = '000000FF';
			$bb->{'y'} += $bb->{'pheight'} / 2;
			$bb->{'x'} -= $bb->{'pwidth'} / 2;
			if($major * 30 > 210 && $major * 30 < 330) {
				$bb->{'x'} += $bb->{'pwidth'} / 4;;
			}

			my $bb = $fb->ttf_print($bb);
		}
		}

		#Draw the gauge
		#

		#
		my $centrex = $x + ($w/2);
		my $centrey = $y + ($h/2);
		my $radius = min($w*0.8, $h*0.9) / 2;

		$fb->set_color(@gauge_color);
		$fb->circle({'x'=>$centrex, 'y'=>$centrey, 'radius'=>$radius, 'filled'=>1});
		$fb->set_color(@black);
		$fb->circle({'x'=>$centrex, 'y'=>$centrey, 'radius'=>$radius, 'filled'=>0});

		$self->drawMajors();
		$self->drawMinors();
		$self->drawNumbers();


		# Save the useful coordinates
		$self->{'radius'} = $radius;
		$self->{'centrex'} = $centrex;
		$self->{'centrey'} = $centrey;
		return $self;
	}


	# Draw the pointer at the angle supplied.
	sub update {
		my $self = shift;
		my $value = shift;

		my $x=$self->{'x'};
		my $y = $self->{'y'};
		my $w=$self->{'width'};
		my $h=$self->{'height'};
		my $centrex = $self->{'centrex'};
		my $radius = $self->{'radius'};
		my $centrey = $self->{'centrey'};
		my $insideradius = 10;

		if($value ne $self->{'oldvalue'}) {

			my $length = 15;
			my $angle = deg2rad($value);
			my $x = $centrex;
			my $y = $centrey;

			# If we have saved the repair details paint those first
			if($self->{'oldxx'} && $self->{'oldyy'}) {
				$xx = $self->{'oldxx'};
				$yy = $self->{'oldyy'};
				$fb->set_color(@gauge_color);
				$fb->line({'x'=>$x, 'y'=>$y, 'xx'=>$self->{'oldxx'}, 'yy'=>$self->{'oldyy'}, 'pixel_size'=>3});
				$fb->set_color(@black);
			}

			# Draw the centre circle
			$fb->set_color(@black);
			$fb->circle({'x'=>$centrex, 'y'=>$centrey, 'radius'=>$insideradius, 'filled'=>1});

			# save the area under the new needle and paint the new needle.
			my $xx = $centrex + (sin($angle) * ($radius - 1));
			my $yy = $centrey - (cos($angle) * ($radius - 1));
			$fb->line({'x'=>$x, 'y'=>$y, 'xx'=>$xx, 'yy'=>$yy, 'pixel_size'=>3});
			$self->drawMajors();
			$self->drawMinors();
			$self->drawNumbers();
			$self->{'oldxx'} = $xx;
			$self->{'oldyy'} = $yy;
		}
		$self->{'oldvalue'} = $value;
	}

}
# vim: set et ts=4 sw=4:
