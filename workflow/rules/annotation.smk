
rule split_multi_allelic:
    input:
        lambda wc: samples[wc.sample],
    output:
        temp("split_multi_allelic/{sample}.vcf")
    conda:
        "../envs/bcftools.yaml"
    log:
        "logs/split_multi_allelic/{sample}.log"
    shell:
        "bcftools norm -m- {input:q} -o {output} &> {log}"


rule add_allelic_fields:
    input:
        "split_multi_allelic/{sample}.vcf",
    output:
        temp("annotated/{sample}.fields_added.vcf"),
    log:
        "logs/add_fields/{sample}.log",
    conda:
        "../envs/rust-script.yaml"
    script:
        "../scripts/generalize_allelic_fields.rs"


rule annotate_variants:
    input:
        calls="annotated/{sample}.fields_added.vcf",
        cache="resources/vep/cache",
        plugins="resources/vep/plugins",
        fasta="resources/genome.fasta",
    output:
        calls=temp("annotated/{sample}.annotated.vcf"),
        stats=temp("annotated/{sample}.stats.html"),
    params:
        # Pass a list of plugins to use, see https://www.ensembl.org/info/docs/tools/vep/script/vep_plugins.html
        # Plugin args can be added as well, e.g. via an entry "MyPlugin,1,FOO", see docs.
        plugins=config["annotations"]["vep"]["plugins"],
        extra="--vcf_info_field ANN {}".format(config["annotations"]["vep"]["params"]),
    log:
        "logs/vep/{sample}.annotate.log",
    threads: max(workflow.cores / len(samples), 1) if len(samples) else 1
    wrapper:
        "0.79.0/bio/vep/annotate"


rule filter_by_annotation:
    input:
        "annotated/{sample}.annotated.vcf",
    output:
        "{output_dir}/{{sample}}.annotated.filtered_ann.vcf".format(
            output_dir=config["general"]["output_path"]
        ),
    log:
        "logs/filter-calls/annotation/{sample}.log",
    params:
        filter=lambda w: config["filter"],
    conda:
        "../envs/vembrane.yaml"
    shell:
        "vembrane filter {params.filter:q} {input} --output-fmt vcf --output {output} &> {log}"


rule get_genome:
    output:
        "resources/genome.fasta",
    params:
        species=config["ref"]["species"],
        datatype="dna",
        build=config["ref"]["build"],
        release=config["ref"]["release"],
    log:
        "logs/get_genome.log",
    cache: True  # save space and time with between workflow caching (see docs)
    wrapper:
        "0.79.0/bio/reference/ensembl-sequence"


rule get_vep_cache:
    output:
        directory("resources/vep/cache"),
    params:
        species="{}_refseq".format(config["ref"]["species"]),
        build=config["ref"]["build"],
        release=config["ref"]["release"],
    log:
        "logs/vep/cache.log",
    cache: True  # save space and time with between workflow caching (see docs)
    wrapper:
        "0.79.0/bio/vep/cache"


rule get_vep_plugins:
    output:
        directory("resources/vep/plugins"),
    params:
        release=config["ref"]["release"],
    log:
        "logs/vep/plugins.log",
    wrapper:
        "0.79.0/bio/vep/plugins"
