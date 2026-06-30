build_smoothing_matrix <- function(target_cells,
                                   nb_order = 1,
                                   include_self = TRUE) {
  n_target <- nrow(target_cells)

  # identify neighbouring grid cells using queen contiguity
  # two cells are neighbours if they share either an edge or a vertex
  nb <- sfdep::st_contiguity(sf::st_geometry(target_cells), queen = TRUE)

  # include higher-order neighbours, if requested
  if (nb_order > 1) {
    nb <- sfdep::st_nb_lag_cumul(nb, order = nb_order)
  }

  edge_i <- rep(seq_along(nb), lengths(nb))
  edge_j <- unlist(nb)

  # convert the neighbour list into a sparse adjacency matrix
  # A[i, j] = 1 indicates that cells i and j are neighbours
  N_matrix <- Matrix::sparseMatrix(
    i = edge_i,
    j = edge_j,
    x = 1,
    dims = c(n_target, n_target)
  )

  # optionally include each cell in its own neighbourhood
  # Diagonal(n_target) creates an identity matrix
  if (include_self) {
    N_matrix <- N_matrix + Matrix::Diagonal(n_target)
  }

  # count the number of neighbours associated with each cell
  row_sums <- Matrix::rowSums(N_matrix)

  # every cell must have at least one neighbour available for smoothing
  if (any(row_sums <= 0)) {
    rlang::abort(
      paste0(
        "At least one target grid cell has no neighbours. ",
        "Use `include_self = TRUE` or a less fragmented grid."
      )
    )
  }

  # row-standardize the adjacency matrix so S_matrix becomes the pycnophylactic
  # smoothing operator. Each row of S_matrix sums to one.
  S_matrix <- N_matrix / row_sums

  S_matrix
}
