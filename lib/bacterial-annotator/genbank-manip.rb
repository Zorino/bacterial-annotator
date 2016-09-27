# -*- coding: utf-8 -*-
# author:  	maxime déraspe
# email:	maxime@deraspe.net
# review:  	
# date:    	15-02-24
# version: 	0.0.1
# licence:  	



class GenbankManip

  attr_accessor :gbk, :coding_seq, :cds_file

  # Initialize then genbank file
  def initialize gbk_file, outdir

    @gbk_file = gbk_file
    if ! File.exists? @gbk_file
      fetch_ncbi_genome(@gbk_file, outdir)
      @gbk_file = "#{outdir}/#{gbk_file}.gbk"
      # @gbk_file += ".gbk"
    end

    flat_gbk = Bio::FlatFile.auto(@gbk_file)

    # Check if gbk is valid
    if flat_gbk.dbclass != Bio::GenBank
      abort "Aborting : The input #{@gbk_file} is not a valid genbank file !"
    else
      @gbk = flat_gbk.next_entry
    end

    @bioseq = @gbk.to_biosequence

  end


  # Prepare CDS/proteins
  def get_cds

    if @coding_seq == nil

      @coding_seq = {}

      # Iterate over each CDS
      @gbk.each_cds do |ft|
        ftH = ft.to_hash
        loc = ft.locations
        gene = []
        product = []
        protId = ""
        if ftH.has_key? "pseudo"
          next
        end
        gene = ftH["gene"] if !ftH["gene"].nil?
        product = ftH["product"] if !ftH["product"].nil?
        protId = ftH["protein_id"][0] if !ftH["protein_id"].nil?
        locustag = ftH["locus_tag"][0] if !ftH["locus_tag"].nil?

        # if ftH.has_key? "translation"
        #   pep = ftH["translation"][0] if !ftH["translation"].nil?
        # else
        #   dna = get_DNA(ft,@bioseq)
        #   pep = dna.translate
        # end

        dna = get_DNA(ft,@bioseq)
        pep = dna.translate
        pepBioSeq = Bio::Sequence.auto(pep)
        dnaBioSeq = Bio::Sequence.auto(dna)

        if protId.strip == ""
          protId = locustag
        end

        @coding_seq[protId] = {protId: protId,
                               location: loc,
                               locustag: locustag,
                               gene: gene[0],
                               product: product[0],
                               bioseq: pepBioSeq,
                               bioseq_gene: dnaBioSeq}
      end

    end

    @coding_seq

  end


  # Print CDS to files
  # RETURN : cds_file path
  def write_cds_to_file outdir

    cds_file = "#{@gbk.accession}.pep"
    dna_file = "#{@gbk.accession}.dna"

    if @coding_seq == nil
      get_cds
    end

    dna_out = File.open("#{outdir}/#{dna_file}", "w")
    File.open("#{outdir}/#{cds_file}", "w") do |fwrite|
      @coding_seq.each_key do |k|
        seqout = @coding_seq[k][:bioseq].output_fasta("#{k}",60)
        seqout_dna = @coding_seq[k][:bioseq_gene].output_fasta("#{k}",60)
        fwrite.write(seqout)
        dna_out.write(seqout_dna)
      end
    end
    dna_out.close

    @cds_file = "#{outdir}/" + cds_file

  end


  # add annotation to a genbank file produced by prodigal
  def add_annotation annotations, outdir, mode, reference_locus

    nb_of_added_ft = 0
    i = 0

    contig = @gbk.definition

    # iterate through
    @gbk.features.each_with_index do |cds, ft_index|

      next if cds.feature != "CDS"

      if mode == 0
        ftArray = []
        cds.qualifiers = []
      else
        ftArray = cds.qualifiers
      end

      i += 1
      prot_id = contig+"_"+i.to_s
      hit = nil
      hit = annotations[prot_id] if annotations.has_key? prot_id

      if hit != nil
        locus, gene, product, note = nil
        locus = hit[:locustag]
        gene = hit[:gene]
        product = hit[:product]
        note = hit[:note]
        pId = hit[:pId]

        if gene != nil
          qGene = Bio::Feature::Qualifier.new('gene', gene)
          ftArray.push(qGene)
        end

        if product != nil
          qProd = Bio::Feature::Qualifier.new('product', product)
          ftArray.push(qProd)
        end

        # check if there is a reference genome.. reference_locus shouldn't be nil in that case
        if locus != nil
          qNote = Bio::Feature::Qualifier.new('note', "corresponds to #{locus} locus (#{pId}% identity) from #{reference_locus.entry_id}")
          ftArray.push(qNote)
        end

        if note != nil
          qNote = Bio::Feature::Qualifier.new('note', note)
          ftArray.push(qNote)
        end


      end
      cds.qualifiers = ftArray

    end

    File.open("#{outdir}/#{contig}.gbk", "w") do |f| 
      f.write(@gbk.to_biosequence.output(:genbank))
    end

    # Bioruby doesn't support gff at this point
    # File.open("#{outdir}/#{contig}.gff", "w") do |f| 
    #   f.write(@gbk.to_biosequence.output(:gff))
    # end

  end


  ###################
  # Private Methods #
  ###################

  # Fct: Get dna sequence
  def get_DNA (cds, seq)
    loc = cds.locations
    sbeg = loc[0].from.to_i
    send = loc[0].to.to_i
    fasta = Bio::Sequence::NA.new(seq.subseq(sbeg,send))
    # position = "#{sbeg}..#{send}"
    if loc[0].strand == -1
      fasta.reverse_complement!
    end
    dna = Bio::Sequence.auto(fasta)
    return dna
  end


  # Fetch genbank genome from NCBI
  def fetch_ncbi_genome refgenome_id, outdir
    Bio::NCBI.default_email = 'default@default.com'
    ncbi = Bio::NCBI::REST.new
    genbankstring = ncbi.efetch(refgenome_id, {"db"=>'nucleotide', "rettype"=>'gb'})
    File.open("#{outdir}/#{refgenome_id}.gbk", "w") do |f|
      f.write(genbankstring)
    end
  end

  private :fetch_ncbi_genome, :get_DNA


end                             # end of Class
