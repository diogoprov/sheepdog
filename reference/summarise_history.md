# Summarise the detection history by site and species

Summarise the detection history by site and species

## Usage

``` r
summarise_history(history)
```

## Arguments

- history:

  A data frame (or tibble) returned by
  [`detection_history()`](https://provetelab.org/sheepdog/reference/detection_history.md).

## Value

A tibble with `site`, `species`, `nights` (nights with any scored
detection) and `nights_k1` to `nights_k3` (nights with detection under
each repetition rule).
