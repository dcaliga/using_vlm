#!/usr/bin/perl

$run = 0;
$clean = 0;
$clobber = 0;
$hw = 0;
$sim = 0;
$dbg = 0;
$compile = 0;
$pbscompile = 0;
$status = 0;

$start_dir = $ENV{'PWD'};

print "running in directory '$start_dir'\n";


@entire_set = (
    "v1",           "ex_using_vlm", "5 64",
    "v1_solution",  "ex_using_vlm", "5 64",
    "v2_solution",  "ex_using_vlm", "5 64",
     );

$ENV{'CC'} = "icc";

if (@ARGV == 0) {
    show_help ();
    }

while (@ARGV) {
        $s = shift @ARGV;
        if ($s eq "-run") {
            $run = 1;
	    # $ENV{'MAPTRACE'} = "1";
            }
	elsif ($s eq "-clean") {
	    $clean = 1;
	    }
	elsif ($s eq "-clobber") {
	    $clobber = 1;
	    }
	elsif ($s eq "-hw") {
	    $hw = 1;
	    }
	elsif ($s eq "-sim") {
	    $sim = 1;
	    }
	elsif ($s eq "-debug") {
	    # print "debug option on\n";
	    $dbg = 1;
	    }
	elsif ($s eq "-compile") {
	    $compile = 1;
	    }
	elsif ($s eq "-help") {
	    show_help ();
	    }
	elsif ($s eq "-h") {
	    show_help ();
	    }
	elsif ($s eq "-pbs") {
	    $pbscompile = 1;
	    }
	else {
	    print "unknown option: '$s'\n";
	    exit 1;
	    }
        }

if ($run) {
    open (LOG, "> log.run");
    }
else {
    open (LOG, "> log.compile");
    }

while (@entire_set) {
    $dir = shift @entire_set;
	$exec_str = shift @entire_set;
	$args = shift @entire_set;

     print  $dir . "  ----  " . $exec_str . "\n";
	# next;

	    system ("pwd");
 print "b4 cd dir\n";
        $stat = chdir $dir;

	    system ("pwd");
 print "before if run\n";

	if ($run) {
	    if ($sim) {
		$xstr = "./" . $exec_str . ".sim " . $args;
                $stat = system $xstr;
		if ($stat == 0) {
		    if ((-e "res_cpu") && (-e "res_map")) {
		        $xstr = "diff res_cpu res_map";
		        $stat = system $xstr;
			}
		    elsif ((-e "res_cpu.pgm") && (-e "res_map.pgm")) {
		        $xstr = "diff res_cpu.pgm res_map.pgm";
		        $stat = system $xstr;
			}
		    elsif ((-e "res_cpu.flt") && (-e "res_map.flt")) {
			check_float ();
			$stat = $err;
		        }

		    if ($stat == 0) {
		        $xstr = "rm -f res_cpu res_map res_cpu.pgm res_map.pgm res_cpu.flt res_map.flt";
			system $xstr;
			}
		    }
	        }
	    elsif ($hw) {
		$xstr = "./" . $exec_str . " " . $args;
                $stat = system $xstr;
		if ($stat == 0) {
		    if ((-e "res_cpu") && (-e "res_map")) {
		        $xstr = "diff res_cpu res_map";
		        $stat = system $xstr;
			}
		    elsif ((-e "res_cpu.pgm") && (-e "res_map.pgm")) {
		        $xstr = "diff res_cpu.pgm res_map.pgm";
		        $stat = system $xstr;
			}
		    elsif ((-e "res_cpu.flt") && (-e "res_map.flt")) {
			check_float ();
			$stat = $err;
		        }

		    if ($stat == 0) {
		        $xstr = "rm -f res_cpu res_map res_cpu.pgm res_map.pgm res_cpu.flt res_map.flt";
			system $xstr;
			}
		    }
		}
	    elsif ($dbg) {
  printf "run dbg\n";
	    printf "$dir\n";
		$xstr = "./" . $exec_str . ".dbg " . $args;
                $stat = system $xstr;
		if ($stat == 0) {
		    if ((-e "res_cpu") && (-e "res_map")) {
		        $xstr = "diff res_cpu res_map";
		        $stat = system $xstr;
			}
		    elsif ((-e "res_cpu.pgm") && (-e "res_map.pgm")) {
		        $xstr = "diff res_cpu.pgm res_map.pgm";
		        $stat = system $xstr;
			}
		    elsif ((-e "res_cpu.flt") && (-e "res_map.flt")) {
			check_float ();
			$stat = $err;
		        }

		    if ($stat == 0) {
		        $xstr = "rm -f res_cpu res_map res_cpu.pgm res_map.pgm res_cpu.flt res_map.flt";
			system $xstr;
			}
		    }
		}

	    if ($stat) {
	        $status = 1;
		}
	    }
	elsif ($clean) {
	    system ("make clean");
	    }
	elsif ($pbscompile) {
 print ("in pbscompile if test\n");
        if ($sim) {
        system ("make simulate");
            }
        elsif ($hw) {
        system ("pwd");
 print ("in pbscompile hw\n");
	    system ("pbs.bl -M make");
            }
        elsif ($dbg) {
        system ("pwd");
 print ("in pbscompile debug\n");
		        $xstr = "pbs.bl -M make debug";
		        $stat = system $xstr;
            }
	    }
	elsif ($clobber) {
	    system ("make clobber");
	    system ("rm -f res_cpu");
	    system ("rm -f res_map");
	    system ("rm -f res.pgm");
	    }
	elsif ($compile) {
 print ("in compile if test\n");
	    if ($sim) {
        $xstr = "make simulate";        
	    $stat = system $xstr;
	        }
	    elsif ($hw) {
	    system ("pwd");
	    system ("make");
	        }
	    elsif ($dbg) {
	    system ("pwd");
 print ("in compile debug\n");
        $xstr = "make debug";        
	    $stat = system $xstr;
	        }

	    if ($stat) {
	        $status = 1;

		if ($stop_on_error) {
	    print "took exit...\n";
		    exit 1;
		    }
		}
		}
	else {
	    print "no options specified; exiting...\n";
	    }

	if (! ($clean || $clobber)) {
	    $stt = ($stat ? "\n    fail" : "\n    succeed\n");
	    print LOG "$dir $stt\n";
	    }

	chdir "../";
        }
	    print "left while entire_set \n";
	chdir $start_dir;

exit $status;

sub show_help {
    print "Options:\n";
    print "  -compile                Compile the suite:\n";
    print "  -run                    Execute the suite:\n";
    print "  -hw                     Compile or run for MAP (default is emulation):\n";
    print "  -debug                  Compile or run in debug mode (default is emulation):\n";
    print "  -clean                  Clean all non-source files except those used to execute\n";
    print "  -pbs                    Run pbs compile";
    print "  -clobber                Clobber all files except sources\n";
    exit 0;
    }

sub check_float {
    open MAP_RES, "< res_map.flt";
    open CPU_RES, "< res_cpu.flt";

    $err = 0;

    while (($m_line = <MAP_RES>) && ($c_line = <CPU_RES>)) {
        chop ($m_line);
        chop ($c_line);

	if ($m_line =~ /\s*(\S+)\s+(\S+)\s(\S+)/) {
	    # print "strings are '$1', '$2', '$3'\n";
	    $index = $1;
	    $v0 = $2;
	    $v1 = $3;
	    }

	if ($c_line =~ /\s*(\S+)\s+(\S+)\s(\S+)/) {
	    # print "strings are '$1', '$2', '$3'\n";
	    $w0 = $2;
	    $w1 = $3;
	    }

        if ($v0 > $w0) {
            $bigger = $v0;
            $smaller = $w0;
            }
        else {
            $bigger = $w0;
            $smaller = $v0;
            }

        if ($smaller != 0.0) {
            $ratio = $bigger/$smaller;
            }
        else {
            $ratio = 10000.0;
            }

        # print "$ratio\n";

        if ($ratio > 1.1) {
            print "index $index, bad compare: $v0 vs $w0\n";
            $err = 1;
            }

        if ($v1 > $w1) {
            $bigger = $v1;
            $smaller = $w1;
            }
        else {
            $bigger = $w1;
            $smaller = $v1;
            }

        if ($smaller != 0.0) {
            $ratio = $bigger/$smaller;
            }
        else {
            $ratio = 10000.0;
            }

        if ($ratio > 1.1) {
            print "index $index, bad compare: $v1 vs $w1\n";
            $err = 1;
            }
        }
    }

