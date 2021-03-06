
my $total = 10;
for(my $i=1; $i <= $total; $i++){
	print "Preparing $i of $total\n";
	


	## get suffix
	my $current= $i . "by1000";
	if($i < 10){
		$current = "0" . $current;
	}
	print $current . "\n";



	## make yaml
	my $current_config = "config/config_mouse_split-$current.yaml";
	my $template = "config_mouse_split-template.yaml";
	open(TEMPLATE, "<$template");
	open(CONFIG_CURRENT, ">$current_config");
	while(<TEMPLATE>){
		s/\{REPLACE\}/$current/g;
		print CONFIG_CURRENT;
	}
	close TEMPLATE;
	close CONFIG_CURRENT;



	## get cun commands
	print "ssh compute-1-X" . "\n";
	print "cd pipeline/mouse_split_up/" . "\n";
	my $snakemake_run=1;
	print "  nohup snakemake --snakefile ../Snakefile --configfile \"${current_config}\" --cores 80 &> \"output/nohup_${current}_${snakemake_run}.out\" &  ";

	print "\n\n";
}
