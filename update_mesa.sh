#!/bin/bash

# The need for the custom steps has been found empirically, by multiple build attempts.
# The commands to run and their arguments have been obtained from the various Meson build scripts.
# Some can (or even must) be run locally at the Mesa repo, then resulting files are copied.
# Others, due to the sheer size of the generated files, are instead run at the Tekisasu build system;
# this script will only copy the needed scripts and data files from Mesa.

check_error() {
    if [ $? -ne 0 ]; then echo "Error!" && exit 1; fi
}

run_custom_steps_at_source() {
    run_step() {
        local P_SUBDIR=$1
        local P_SCRIPT_PLUS_ARGS=$2
        local P_REDIR_TARGET=$3

        echo "Custom step: [$P_SUBDIR] $P_SCRIPT_PLUS_ARGS"

        local OUTDIR=$TEKISASU_DIR/tekisasu-mesa/$P_SUBDIR
        mkdir -p $OUTDIR
        check_error
        pushd ./mesa/$P_SUBDIR > /dev/null
        check_error
        eval "local COMMAND=\"$P_SCRIPT_PLUS_ARGS\""
        if [ ! -z "$P_REDIR_TARGET" ]; then
            eval "TARGET=\"$P_REDIR_TARGET\""
            python3 $COMMAND > $TARGET
        else
            python3 $COMMAND
        fi
        check_error
        popd > /dev/null
        check_error
    }

    run_step bin 'git_sha1_gen.py --output $OUTDIR/git_sha1.h'
    run_step src/compiler/spirv 'spirv_info_c.py spirv.core.grammar.json $OUTDIR/spirv_info.c'
    run_step src/compiler/spirv 'vtn_gather_types_c.py spirv.core.grammar.json $OUTDIR/vtn_gather_types.c'
}

copy_file() {
    echo "Copying $1/$2"
    mkdir -p tekisasu-mesa/$1
    check_error
    cp ./mesa/$1/$2 tekisasu-mesa/$1
    check_error
}

copy_custom_steps_sources() {
    copy_file src/compiler/glsl ir_expression_operation.py
    copy_file src/compiler/nir nir_builder_opcodes_h.py
    copy_file src/compiler/nir nir_constant_expressions.py
    copy_file src/compiler/nir nir_intrinsics.py
    copy_file src/compiler/nir nir_intrinsics_h.py
    copy_file src/compiler/nir nir_intrinsics_c.py
    copy_file src/compiler/nir nir_intrinsics_indices_h.py
    copy_file src/compiler/nir nir_opcodes.py
    copy_file src/compiler/nir nir_opcodes_h.py
    copy_file src/compiler/nir nir_opcodes_c.py
    copy_file src/compiler/nir nir_algebraic.py
    copy_file src/compiler/nir nir_opt_algebraic.py
    copy_file src/compiler/spirv spir-v.xml
    copy_file src/compiler/spirv vtn_generator_ids_h.py
    copy_file src/microsoft/compiler dxil_nir_algebraic.py
    copy_file src/util format_srgb.py
    copy_file src/util/format u_format.csv
    copy_file src/util/format u_format_pack.py
    copy_file src/util/format u_format_parse.py
    copy_file src/util/format u_format_table.py
}

copy_sources() {
    copy_subir_sources() {
        echo "Copying [.c/.cpp/.h] $1/"
        mkdir -p tekisasu-mesa/$1
        check_error
        find ./mesa/$1 -maxdepth 1 \( -name '*.c' -or -name '*.cpp' -or -name '*.h' \) -exec cp {} tekisasu-mesa/$1 \;
        check_error
    }

    copy_subir_headers() {
        echo "Copying [.h] $1/"
        mkdir -p tekisasu-mesa/$1
        check_error
        find ./mesa/$1 -maxdepth 1 -name '*.h' -exec cp {} tekisasu-mesa/$1 \;
        check_error
    }

    # These are the first we know for sure we want to copy.
    copy_file . .editorconfig
    copy_subir_sources src/microsoft/compiler
    copy_subir_sources src/microsoft/spirv_to_dxil
    # The need for these have been found by multiple build attempts.
    # Initially, we copy only the headers. Later, we promote some to be
    # copied with sources, as advised by linker errors.
    # Multiple rounds of such procedure may be needed.
    copy_subir_headers bin
    copy_subir_headers include
    copy_subir_headers include/GL
    copy_subir_headers include/GLES
    copy_subir_headers include/GLES2
    copy_subir_headers include/GLES3
    copy_subir_headers include/KHR
    copy_subir_headers src/c11
    copy_file src/c11/impl threads_win32.*
    copy_file src/c11/impl time.c
    copy_subir_sources src/compiler
    copy_subir_headers src/compiler/glsl
    copy_subir_sources src/compiler/nir
    copy_subir_sources src/compiler/spirv
    copy_subir_headers src/gallium/include/pipe
    copy_subir_headers src/mesa/main
    copy_subir_headers src/mesa/program
    copy_subir_sources src/util/format
    copy_subir_sources src/util/sha1
    copy_file src/vulkan/runtime vk_object.h
    copy_file src/vulkan/runtime vk_ycbcr_conversion.h
    copy_file src/vulkan/util vk_format.h
    # With non-header files in src/util/ we have to be selective,
    # since many of the source files there are not needed and
    # on top of that will cause build errors.
    # We still take the liberty to copy all the headers.
    copy_subir_headers src/util
    copy_file src/util blob.c
    copy_file src/util bitscan.c
    copy_file src/util double.c
    copy_file src/util half_float.c
    copy_file src/util hash_table.c
    copy_file src/util log.c
    copy_file src/util mesa-sha1.c
    copy_file src/util memstream.c
    copy_file src/util os_misc.c
    copy_file src/util ralloc.c
    copy_file src/util rb_tree.c
    copy_file src/util rgtc.c
    copy_file src/util set.c
    copy_file src/util simple_mtx.c
    copy_file src/util softfloat.c
    copy_file src/util string_buffer.c
    copy_file src/util u_call_once.c
    copy_file src/util u_debug.c
    copy_file src/util u_printf.c
    copy_file src/util u_qsort.cpp
    copy_file src/util u_vector.c
    copy_file src/util u_worklist.c

    cp ./mesa/VERSION tekisasu-mesa/VERSION.info
    check_error
}

blacklist_sources() {
    # These are programs. Not needed and makes build hungrier for dependencies.
    rm tekisasu-mesa/src/compiler/spirv/spirv2nir.c
    check_error
    rm tekisasu-mesa/src/microsoft/spirv_to_dxil/spirv2dxil.c
    check_error
}

tweak_gitignore() {
    # bin/ is globally Git-ignored; we need the one of Mesa.
    echo '!bin/' > tekisasu-mesa/.gitignore
    check_error
    echo 'generated/' >> tekisasu-mesa/.gitignore
    check_error
}

custom_source_gen() {
    run_step() {
        local P_SUBDIR=$1
        local P_SCRIPT_PLUS_ARGS=$2
        local P_REDIR_TARGET=$3

        echo "Custom step: [$P_SUBDIR] $P_SCRIPT_PLUS_ARGS"

        local OUTDIR=$TEKISASU_DIR/tekisasu-mesa/$P_SUBDIR
        local GENDIR=$TEKISASU_DIR/tekisasu-mesa/generated/$P_SUBDIR
        mkdir -p $GENDIR
        check_error
        pushd $OUTDIR > /dev/null
        check_error
        eval "local COMMAND=\"$P_SCRIPT_PLUS_ARGS\""
        if [ ! -z "$P_REDIR_TARGET" ]; then
            eval "TARGET=\"$P_REDIR_TARGET\""
            python3 $COMMAND > $GENDIR/$TARGET
        else
            python3 $COMMAND
        fi
        check_error
        popd > /dev/null
        check_error
    }
   
    run_step 'src/compiler' 'glsl/ir_expression_operation.py enum' 'ir_expression_operation.h'
    run_step 'src/compiler/nir' 'nir_builder_opcodes_h.py' 'nir_builder_opcodes.h'
    run_step 'src/compiler/nir' 'nir_constant_expressions.py' 'nir_constant_expressions.c'
    run_step 'src/compiler/nir' 'nir_intrinsics_h.py --outdir $GENDIR'
    run_step 'src/compiler/nir' 'nir_intrinsics_c.py --outdir $GENDIR'
    run_step 'src/compiler/nir' 'nir_intrinsics_indices_h.py --outdir $GENDIR'
    run_step 'src/compiler/nir' 'nir_opcodes_h.py' 'nir_opcodes.h'
    run_step 'src/compiler/nir' 'nir_opcodes_c.py' 'nir_opcodes.c'
    run_step 'src/compiler/nir' 'nir_opt_algebraic.py' 'nir_opt_algebraic.c'
    run_step 'src/compiler/spirv' 'vtn_generator_ids_h.py spir-v.xml $GENDIR/vtn_generator_ids.h'
    run_step 'src/microsoft/compiler' 'dxil_nir_algebraic.py -p ../../../src/compiler/nir' 'dxil_nir_algebraic.c'
    run_step 'src/util' 'format_srgb.py' 'format_srgb.c'
    run_step 'src/util/format' 'u_format_table.py u_format.csv --header' 'u_format_pack.h'
    run_step 'src/util/format' 'u_format_table.py u_format.csv' 'u_format_table.c'
}


TEKISASU_DIR=$(pwd)

if [ -d ./tekisasu-mesa ]; then
    echo "Clearing tekisasu-mesa/"
    find tekisasu-mesa -mindepth 1 -type d | xargs rm -rf
fi

run_custom_steps_at_source
copy_custom_steps_sources
copy_sources
blacklist_sources
tweak_gitignore

if [ -d ./tekisasu-patches ]; then
    echo "Applying patches"
    find ./tekisasu-patches -name '*.patch' -exec git apply {} \;
fi

custom_source_gen
