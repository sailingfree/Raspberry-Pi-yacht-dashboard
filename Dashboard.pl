#!/usr/bin/perl
#
use Graphics::Framebuffer;

use Data::Dumper;

use LWP::UserAgent;

use JSON;

use Scalar::Util qw(looks_like_number);

our $RUNNING = 1;
sub sighan {
	$RUNNING = 0; 
	$fb->cls('ON');
	print STDOUT "Quitting.\n";
	exit;
}

our $fb = Graphics::Framebuffer->new('SPLASH'=>0,'SHOW_ERRORS'=>1, 'ACCELERATED'=>1, 'RESET'=>0);
$fb->cls('OFF'); # Clear screen and turn off the console cursor
$SIG{'QUIT'} = \&sighan;
$SIG{'INT'} = \&sighan;
$SIG{'HUP'} = \&sighan;
$SIG{'TERM'} = \&sighan;

my $xres = $fb->{'XRES'};
my $yres = $fb->{'YRES'};

# Create the main background and fill it.§
##
$fb->normal_mode();
$fb->set_color({'red' => 128, 'green' => 128, 'blue' => 128, 'alpha' => 255});
$fb->box({'x'=>0, 'y'=>0, 'xx'=>$xres, 'yy'=>$yres, 'radius'=>0,'filled'=>1});



# Paths for the font we want.
my $path = '/usr/share/fonts/truetype/liberation2';
my $face = 'LiberationSans-Bold.ttf';

# Create the instruments to display
my $sog = Numeric->new(0, 0, $xres/3 ,$yres/3,'SOG');
my $wtrue = Numeric->new($xres/3, 0, $xres/3 ,$yres/3,'Wind Speed (T)');
my $wangle = Numeric->new(2* $xres/3, 0, $xres/3 ,$yres/3,'Wind Angle (T)');
my $d = Numeric->new(0, $yres/3, $xres/3 ,$yres/3,'Depth');
my $hdg = Numeric->new($xres/3, $yres/3, $xres/3 ,$yres/3,'Heading');

# Main look to read the signal k source parse the result and display
# the instruments
sub signalk_handler {
	do {
		my $ua = LWP::UserAgent->new;
		my $url = 'http://localhost:443/signalk/v1/api/';
		my $req = HTTP::Request->new(GET=>$url);
		$req->header('content-type'=>'application/json');
		my $resp = $ua->request($req);
		my $msg = $resp->decoded_content;
		print STDOUT "Signalk\n";
		my $sc = decode_json($msg);
		$Data::Dumper::Indent = 1;
		my $urn = $sc->{'self'};
		$urn =~ s/vessels\.//;
		print STDOUT Dumper($sc);

		my $depth = $sc->{'vessels'}->{$urn}->{'environment'}->{'depth'}->{'belowTransducer'}->{'value'};

		my $wind = $sc->{'vessels'}->{$urn}->{'environment'}->{'wind'}->{'speedTrue'}->{'value'};
		my $windangle = $sc->{'vessels'}->{$urn}->{'environment'}->{'wind'}->{'angleApparent'}->{'value'};
		my $speedoverground = $sc->{'vessels'}->{$urn}->{'navigation'}->{'speedOverGround'}->{'value'};
		my $headingTrue = $sc->{'vessels'}->{$urn}->{'navigation'}->{'headingTrue'}->{'value'};
		$d->updateFloat($depth);
		$wtrue->updateFloat($wind * 1.943);	## Convert m/s to knots
		$wangle->updateAngle($windangle);
		$sog->updateFloat($speedoverground * 1.943);	## Convert m/s to knots
		$hdg->updateAngle($headingTrue);
		sleep(1);
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
			'x' => shift,
			'y' => shift,
			'width' => shift,
			'height' =>shift,
			'label' => shift,
			'value' => shift
		};

		bless $self, $class;
		$fb->set_color({'red' => 128, 'green' => 0, 'blue' => 0, 'alpha' => 255});
		$fb->rbox({'x'=>$self->{'x'}, 'y'=>$self->{'y'}, 'width'=>$self->{'width'}, 'height'=>$self->{'height'}, 'radius'=>4,'filled'=>0,'pixel_size'=>1});

		my $x=$self->{'x'};
		my $y = $self->{'y'};
		my $w=$self->{'width'};
		my $h=$self->{'height'};
		my $bb = $fb->ttf_print({'x'=>0,
				'y'=>$y + 60,
				'height'=>32,
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
		$bb->{'x'} = $x + ($w /2) - ($bb->{'pwidth'} / 2);
		$bb->{'y'} = $y + $bb->{'pheight'};
		$bb->{'color'} = '000000FF';

		my $bb = $fb->ttf_print($bb);

		return $self;
	}

	sub updateFloat {
		my $self = shift;
		my $value = shift;	
		if(looks_like_number($value)) {
			$self->update(sprintf("%.2f", $value));
		} else {
			$self->update("--.--");
		}
	}

	sub updateAngle {
		my $self = shift;
		my $value = shift;
		if(looks_like_number($value)) {
			$self->update(int($value * 57.52) . ' ');
		} else {
			$self->update("---");
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

		if(!defined($self->{'lastValue'}) || $value != $self->{'lastValue'}) {
			$fb->normal_mode();
			# Blank the old value using the old bounding box
			if($oldbb) {
				$fb->rbox({'x'=>$oldbb->{'x'},
						'y'=>$oldbb->{'y'} - $oldbb->{'pheight'}, 
						'width'=>$oldbb->{'pwidth'}, 
						'height'=>$oldbb->{'pheight'}, 
						'radius'=>0,
						'filled'=>1});
			}
			my $bb = $fb->ttf_print(
				{'x'=>$x,
					'y'=>$y + $h,
					'height'=>74,
					'wscale' => 1,
					'color'=>'00000000',
					'text'=>$value . ' ',
					'font_path'=>$path,
					'face'=>$face,
					'bounding_box' => TRUE,
					'center' => CENTER_X,
					'antialias' => TRUE});

			# Now we've got the bounding box 
			# Center the text in the middle of the bottom half
			$bb->{'x'} = $x + ($w / 2) - ($bb->{'pwidth'} /2 );

			$fb->set_color({'red' => 128, 'green' => 128, 'blue' => 128, 'alpha' => 255});

			# Print the bounding box with the new width 
			$bb->{'color'} = '000000FF';
			$fb->ttf_print($bb);

			# Save the current bb for next time
			$self->{'oldbb'} = $bb;

		}
		$self->{'lastValue'} = $value;
	}
}

# vim: set et ts=4 sw=4:
