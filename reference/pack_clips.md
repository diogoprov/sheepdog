# Pack the clips into one zip per species

Zips each species folder of `<output_dir>/clips` into
`<output_dir>/packages/<species_folder>.zip`: light validation packages
to send to the reviewers.

## Usage

``` r
pack_clips(manifest, output_dir)
```

## Arguments

- manifest:

  A data frame, the clip manifest (one row per clip), as returned by
  [`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md).

- output_dir:

  Character scalar, the `output_dir` given to
  [`cut_clips()`](https://provetelab.org/sheepdog/reference/cut_clips.md).

## Value

The paths of the zip files, invisibly.
