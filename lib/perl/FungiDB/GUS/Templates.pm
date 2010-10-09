package FungiDB::GUS::Templates;

use Moose;
use XML::Simple;
use XML::Writer;
use IO::File;
extends FungiDB;



# Dump out a rather generic datasource file for a new organism
sub generate_isf_datasource {
    my ($self,$genus,$species,$strain) = @_;
    
    # filenames are located at ApiCommonData/Load/lib/xml/datasources/fungidb;    
    # filenames are "genus_species_strain.xml", eg cryptococcus_neoformans_grubii_h99.xml
    
    # A symbolic name, used both in the database as well as for file names.
    my $symbolic_name = join("_",$genus,$species,$strain);
    
    my $filename = "$symbolic_name.xml";
    
    my $fh = new IO::File(">$root/$filename");
    my $write = new XML::Writer(OUTPUT => $fh);
    
    my $date = `date +%Y-%m-%d`;
    chomp $date;
    
    $writer->startTag('resources');
    $writer->comment("$genus $species, strain $strain ISF resource; generated $date");

    # FASTA
    $writer->startTag('resource',
		      
		      # Chromosomes
		      resource => "${symbolic_name}_chromosomes_RSRC",
		      
		      # Version is a macro
		      version  => '@@' . $symbolic_name . '_chromosomes_VER@@', 
		      
		      # Plugin for loading FASTA
		      plugin   => 'GUS::Supported::Plugin::LoadFastaSequences'
		      );
    
    $writer->emptyTag('manualGet',		      
		      # Data location, standardized paths and file names required.
		      fileOrDir => "FungiDB/$symbolic_name/genome/chromosomes/" . '%RESOURCE_VERSION%' 
		      . "${symbolic_name}_supercontigs.fasta");
    
    # Plugin Arguments
    $writer->startTag('pluginArgs');
    $writer->comment('The following arguments may need to be tweaked depending on source: ncbiTaxId, regexChromosome, regexSourceId, SOTermName');
    
    my $seq_file = $symbolic_name . '_supercontigs.fasta';
    $writer->raw(
		 qq[--externalDatabaseName %RESOURCE_NAME%                   
		    --externalDatabaseVersion %RESOURCE_VERSION%
		    --sequenceFile @@dataDir@@/$seq_file 
		    --tableName "DoTS::ExternalNASequence" 
		    --ncbiTaxId $taxon_id 
		    --regexChromosome '\d+\.(\d+)'
		    --regexSourceId  '>(\S+)' 
		    --SOTermName 'chromosome'
		    ]);
    $writer->endTag();   # </pluginArgs>
    
    # Meta
    $writer->startTag('info',
		      displayName => $display_name,
		      project     => 'FungiDB',  # hard-coding project.
		      organisms   => '@@' . $symbolic_name . '_OrganismFullName@@',
		      category    => 'Genome',
		      publicUrl   => '',
		      contact     => '',
		      email       => '',
		      institution => '',
		      );
    
    # A prose description
    $writer->startTag('description');
    $writer->character("Sequence data from $source");
    $writer->endTag();  # </description>
    
    $writer->endTag();  # </info>
    
    $writer->endTag();  # </resource>
    
    ###########################
    # GFF-based annotations
###########################    
    $writer->startTag('resource',
		      resource => "${symbolic_name}_annotations_RSRC",
		      
		      # Version is a macro but tied to the parent resource
		      version  => '@@' . $symbolic_name . '_chromosomes_VER@@', 
		      
		      parentResource => "${symbolic_name}_chromosomes_RSRC",
		      
		      # Plugin for loading sequence features
		      plugin   => 'GUS::Supported::Plugin::InsertSequenceFeatures'
		      );
    
    $writer->emptyTag('manualGet',		      
		      # Data location, standardized paths and file names required.
		      fileOrDir => "FungiDB/$symbolic_name/genome/chromosomes/" . '%RESOURCE_VERSION%' 
		      . "${symbolic_name}_transcripts.gff3");
    
    # Unpacking arguments
    $writer->startTag('unpack');
    $writer->raw("preprocessGFF3 --input_gff @@dataDir@@/${symbolic_name}_transcripts.gff3 --output_gff @@dataDir@@/${symbolic_name}.transformed.gff");
    
    # Plugin Arguments
    $writer->startTag('pluginArgs');
    $writer->comment('The following arguments may need to be tweaked depending on source: mapFile');
    
    $writer->raw(
		 qq[--mapFile @@gusHome@@/lib/xml/isf/FungiDB/broadGFF32Gus.xml
		    --inputFileExtension "gff"
		    --fileFormat gff3
		    --defaultOrganism "Cryptococcus neoformans var. grubii H99"
		    --seqSoTerm "chromosome"
		    --extDbName %PARENT_RESOURCE_NAME%
		    --extDbRlsVer %PARENT_RESOURCE_VERSION%
		    --inputFileOrDir @@dataDir@@/$symbolic_name.transformed.gff
		    --soCvsVersion @@SO_VER@@
		    --validationLog @@dataDir@@/validation.log 
		    --bioperlTreeOutput @@dataDir@@/bioperlTree.out
		    --seqIdColumn source_id
		    --naSequenceSubclass ExternalNASequence
		    ]);
    $writer->endTag();   # </pluginArgs>
    
    # Meta
    $writer->startTag('info',
		      displayName => "$display_name genome sequence and annotation",
		      project     => 'FungiDB',  # hard-coding project.
		      organisms   => '@@' . $symbolic_name . '_OrganismFullName@@',
		      category    => 'Genome',
		      publicUrl   => '',
		      contact     => '',
		      email       => '',
		      institution => '',
		      );
        
    # A prose description
    $writer->startTag('description');
    $writer->character("Sequence data from $source");
    $writer->endTag();  # </description>
    
    $writer->endTag();  # </info>
    
    $writer->endTag();  # </resource>
    $writer->endTag();  # </resources>
    
    $writer->end();
    $fh->close();
}


=head1 Example resources file, 2010.10
    
<resources>
<!--c_neoformans_grubiiISFResource-->
  <resource resource="cryptococcus_neoformans_grubii_h99_chromosomes_RSRC" version="@@cryptococcus_neoformans_grubii_h99_chromosomes_VER@@"
      plugin="GUS::Supported::Plugin::LoadFastaSequences">
    <manualGet fileOrDir="FungiDB/cryptococcus_neoformans_grubii_h99/genome/chromosome/%RESOURCE_VERSION%/cryptococcus_neoformans_grubii_h99_supercontigs.fasta"/>
    <pluginArgs>--externalDatabaseName %RESOURCE_NAME% --ncbiTaxId 235443 --externalDatabaseVersion %RESOURCE_VERSION% --sequenceFile @@dataDir@@/cryptococcus_neoformans_grubii_h99_supercontigs.fasta --SOTermName 'chromosome'  --regexSourceId  '>(\S+)' --tableName "DoTS::ExternalNASequence" --regexChromosome '\d+\.(\d+)' </pluginArgs>
    <info
        displayName="C. neoformans var. grubii (strain H99, serotype A) chromosomes sequence and annotation"
        project="FungiDB"
        organisms="@@cryptococcus_neoformans_grubii_h99_OrganismFullName@@"
        category="Genome"
        publicUrl=""
        contact=""
        email=""
        institution="Broad">
      <description>
        <![CDATA[
         Sequence data from Broad.
        ]]>
      </description>
    </info>
  </resource>

<resource resource="cryptococcus_neoformans_grubii_h99_annotations_RSRC" version="@@cryptococcus_neoformans_grubii_h99_chromosomes_VER@@" parentResource="cryptoccus_neoformans_grubii_h99_chromosomes_RSRC"
      plugin="GUS::Supported::Plugin::InsertSequenceFeatures">


    <manualGet fileOrDir="FungiDB/cryptococcus_neoformans_grubii_h99/genome/chromosome/%RESOURCE_VERSION%/cryptococcus_neoformans_grubii_h99_transcripts.gff3"/> 
    <unpack>preprocessGFF3 --input_gff @@dataDir@@/cryptococcus_neoformans_grubii_h99_transcripts.gff3 --output_gff @@dataDir@@/cryptococcus_neoformans_grubii_h99.transformed.gff</unpack>
    <pluginArgs>--extDbName %PARENT_RESOURCE_NAME% --extDbRlsVer %PARENT_RESOURCE_VERSION% --mapFile @@gusHome@@/lib/xml/isf/FungiDB/broadGFF32Gus.xml --inputFileOrDir @@dataDir@@/cryptococcus_neoformans_grubii_h99.transformed.gff --inputFileExtension "gff"  --fileFormat gff3 --soCvsVersion @@SO_VER@@ --defaultOrganism "Cryptococcus neoformans var. grubii H99"  --seqSoTerm "chromosome" --validationLog @@dataDir@@/validation.log --bioperlTreeOutput @@dataDir@@/bioperlTree.out --seqIdColumn source_id --naSequenceSubclass ExternalNASequence</pluginArgs>
    <info
        displayName="Cryptococcus neoformans var. grubii strain H99 chromosomes sequence and annotation"
        project="FungiDB"
        organisms="@@cryptococcus_neoformans_grubii_h99_OrganismFullName@@"
        category="Genome"
        publicUrl=""
        contact=""
        email=""
        institution="Broad and Duke">
      <description>
        <![CDATA[
         ]]>
      </description>
    </info>
  </resource>

</resources>




=pod
    
    no Moose;

    1;





