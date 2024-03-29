###############################################################################
# PLOT GENE MAPS                                                              #
###############################################################################
# A R framework to plot comparison of gene stretches, à la Artemis, but
# with production-like graphics, and a static interface
################################################################################
# Plotting function
################################################################################
# plot frame, makes space for tree and legend if necessary
plot_gene_map <- function(dna_segs,
                          comparisons=NULL,
                          extra_comparisons=NULL,
                          extra_comparisons_map=NULL,
                          dna_shift=NULL,
                          tree=NULL,
                          tree_width=NULL, # in inches
                          tree_branch_labels_cex=NULL,
                          legend=NULL, # unimplemented
                          annotations=NULL,
                          annotation_height=1, # height of annot line
                          annotation_cex=0.8, # size of annotations
                          xlims=NULL,
                          offsets=NULL, # regulates manually alignment of segs
                          minimum_gap_size=0.05,
                          fixed_gap_length=FALSE,
                          limit_to_longest_dna_seg=TRUE,
                          main=NULL, # main title
                          main_pos="centre", # centre, left, right
                          dna_seg_labels=NULL, # labels on dna_segs
                          dna_seg_label_cex=1, # size of these
                          dna_seg_label_col="black", # color of these
                          gene_type=NULL, # if not null, resets gene_type
                          arrow_head_len=200, # force arrow head length
                          dna_seg_line=TRUE,  # draw a line on each dna_seg
                          scale=TRUE,         # scale in the bottom right
                          dna_seg_scale=!scale, # scale on each dna_seg
                          n_scale_ticks=7,    # number of tick marks for these
                          scale_cex=0.6,      # size of text on scale
                          global_color_scheme=c("auto", "auto",
                            "blue_red", 0.5),
                          override_color_schemes=FALSE,
                          plot_new=TRUE, # FALSE to integrate on a bigger plot
                          debug=0){
  #----------------------------------------------------------------------------#
  # check arguments
  #----------------------------------------------------------------------------#
  ### objects ###
  # dna_segs
  if (missing(dna_segs)) stop("Argument dna_segs must be provided")
  if (!is.list(dna_segs) || !all(sapply(dna_segs, is.dna_seg)))
    stop("Argument dna_segs must be a list of dna_seg objects")
  n_dna_segs <- length(dna_segs)
  n_rows <- 2*n_dna_segs-1
  
  # comparisons
  n_comparisons <- length(comparisons)
  if (n_comparisons > 1){
    if (!is.list(comparisons) || !all(sapply(comparisons, is.comparison)))
      stop("Argument comparisons must be a list of comparison objects")
  }
  # check that there are enough comparisons compared to dna segments
  if (n_comparisons > 0 && !(n_dna_segs - n_comparisons == 1))
    stop("Number of comparisons not correct")
    
  # extra comparisons
  n_extra_comparisons <- length(extra_comparisons)
  if (n_extra_comparisons > 1) {
    if (!is.list(extra_comparisons) || !all(sapply(extra_comparisons, is.comparison)))
      stop("Argument extra_comparisons must be a list of comparison objects ")
    if (!is.list(extra_comparisons_map) || !all(sapply(extra_comparisons_map, function(x) is.vector(x) && (length(x) == 2) && is.numeric(x))))
      stop("Argument extra_comparisons_map must be a list of vectors of two numbers")
  }
    
  # if there is no shift list, make one
  if (is.null(dna_shift)) {
  	dna_shift<-as.list(rep(0,n_dna_segs))  
  } else if (length(dna_shift) != n_dna_segs) {
    stop("Argument dna_shift doesn't have the same length as dna_segs")
  } 
    
  # if dna_seg is a named list, attribute names to dna_seg_labels
  if (is.null(dna_seg_labels) && !is.null(dna_segs)){
    dna_seg_labels <- names(dna_segs)
  }
  
  # check length of labels
  if (!is.null(dna_seg_labels) && !(length(dna_seg_labels) == n_dna_segs))
    stop("Argument dna_seg_labels doesn't have the same length as dna_segs")

  # check dna_seg_label colors
  if (length(dna_seg_label_col) == 1){
    dna_seg_label_col <- rep(dna_seg_label_col, n_dna_segs)
  }
  else if (!length(dna_seg_label_col) == n_dna_segs){
    stop("Length of argument dna_seg_label_col must be 1 or as dna_segs")
  }
  
  # check tree
  if (!is.null(tree)){
    if (!inherits(tree, "phylog"))
      stop("Argument tree should be of class phylog (ade4)")    
    # check correspondence between names (given by names(comparison) or
    # dna_seg_labels) and tree leaves
    if (is.null(dna_seg_labels))
      stop("If tree is given, label names should be provided via named list dna_segs or dna_seg_labels")
    # check that number of leaves corresponds to number of segs
    if (length(tree$leaves) != n_dna_segs)
      stop("Number of leaves in the tree not equal to number of dna segs")
    if (!all(dna_seg_labels %in% names(tree$leaves)))
      stop("Tree leaves not corresponding to dna_seg labels")
    # check whether nodes have added labels
    if (is.null(tree_branch_labels_cex)){
      if (length(grep("^[^I]", names(tree$nodes)))) {
        tree_branch_labels_cex <- 0.8
      } else {
        tree_branch_labels_cex <- 0
      }
    }
  }

  # check annotation
  if (!is.null(annotations)){
    # if there is only one annotation, put it on the top
    if (is.annotation(annotations)){
      annot <- annotations
      annotations <- c(list(annot), rep(list(NULL), n_dna_segs-1))
    } else if (length(annotations) == n_dna_segs){
      if (!all(sapply(annotations, function(x) is.annotation(x) || is.null(x))))
        stop("All elements of annotations should be NULL or annotation objects")
    } else stop ("annotation must be of same length as dna_segs")
    annot_h <- ifelse(sapply(annotations, is.null), 0, annotation_height)
  } else {
    annot_h <- rep(0, n_dna_segs)
  }
  
  ### graphical arguments ###
  # check xlims
  if (!is.null(xlims)){
    if (!is.list(xlims))
      stop("xlims must be a list")
    if (length(xlims) != n_dna_segs)
      stop("xlims must be of the same length as dna_segs")
    if (!all(sapply(xlims, function(x) (length(x) %% 2) == 0)))
      stop("All elements of xlims should have an even number of elements")
    for (i in 1:length(xlims)){
      xlim <- xlims[[i]]
      # check numeric, replace null and inf values
      rng <- range(dna_segs[[i]])
      min <- rng[1] - 0.02*diff(rng)
      max <- rng[2] + 0.02*diff(rng)
      # replace NULL value by min-max
      if (is.null(xlim)) xlim <- c(min, max)
      # replace -Inf and Inf by min max
      xlim[xlim == -Inf] <- min
      xlim[xlim == Inf] <- max
      # check that all are numeric
      if (!is.numeric(xlim)) stop("All elements of xlims should be numeric")
      # transform to data.frame
      xlim <- data.frame(matrix(xlim, ncol=2, byrow=TRUE))
      names(xlim) <- c("x0", "x1")
      # check the strand
      xlim$strand <- ifelse(xlim$x0 < xlim$x1, 1, -1)
      # sort x0 x1
      for (j in 1:nrow(xlim)) xlim[j,1:2] <- sort(xlim[j,1:2])
      xlims[[i]] <- xlim
    }
  } else {
    xlims <- list()
    for (i in 1:n_dna_segs){
      rng <- range(dna_segs[[i]])
      xlims[[i]] <- data.frame(x0=rng[1] - 0.02*diff(rng),
                               x1=rng[2] + 0.02*diff(rng),
                               strand=1)
    }
  }
 
  # check offsets
  if (!is.null(offsets) && length(offsets) != n_dna_segs){
    stop("Length of offsets not equal to number of dna_segs")
  }
  
  # check main_pos
  if (main_pos == "centre"){
    main_x <- 0.5
    main_just <- "centre"
  } else if (main_pos == "left"){
    main_x <- 0
    main_just <- "left"
  } else if (main_pos == "right"){
    main_x <- 1
    main_just <- "right"
  } else {
    stop("main_pos should be one of centre, left, right")
  }

  # check dna_seg_line
  if (is.logical(dna_seg_line)) {
    dna_seg_line <- as.character(dna_seg_line)
    dna_seg_line[dna_seg_line == "TRUE"] <- "black"
  }
  if (!is.character(dna_seg_line ))
    stop("dna_seg_line should be eiher a logical or character giving color")
  if (length(dna_seg_line) == 1){
    dna_seg_line <- rep(dna_seg_line, n_dna_segs)
  } else if (length(dna_seg_line) != n_dna_segs){
    stop("dna_seg_line should be of length 1 or same length as dna_segs")
  }
  
  # check gene_type
  if (!is.null(gene_type) && !(gene_type %in% gene_types()))
    stop(paste("gene_type muste be one of:",
               paste(gene_types(), collapse=", ")))

  # check scale. Must be logical
  if (is.logical(dna_seg_scale)){
    # if length 1, make dna_seg_scale the same length as dna_segs
    if (length(dna_seg_scale) == 1){
      dna_seg_scale <- rep(dna_seg_scale, n_dna_segs)
    }
    # if a different length, must be of the same length as n_dna_segs
    else if (length(dna_seg_scale) != n_dna_segs){
      stop("dna_seg_scale must be the same length dna_segs")
    }
  }
  else {
    stop("dna_seg_scale must be logical")
  }

  # check global_color_scheme
  if (length(global_color_scheme) != 4)
    stop ("global_color_scheme should be length 4")
  # accepted values for second value
  glob_col_sch_2_vals <- c("increasing", "decreasing", "auto")
  if (length(grep(global_color_scheme[2], glob_col_sch_2_vals)) != 1){
    stop(paste("Second argument to global_color_scheme should be one of",
               paste(glob_col_sch_2_vals, collapse=", ")))
  } else {
    global_color_scheme[2] <- grep(global_color_scheme[2],
                                   glob_col_sch_2_vals, value=TRUE)
  }
  
  #----------------------------------------------------------------------------#
  # plotting options
  #----------------------------------------------------------------------------#
  # dna_seg lines height. 1 line for the dna_seg, 0.5 in addition for
  # the dna_seg_scale, if needed. 1 null in between for comparisons
  # to rewrite sometimes
  h <- rep(1, n_rows)
  h[seq(1, n_rows, by=2)] <- 1 + scale_cex*dna_seg_scale + annot_h
  dna_seg_heights <- unit(h, c(rep(c("lines", "null"), n_rows), "lines"))
  
  # deal with resetting symbols
  if (!is.null(gene_type)){
    if (gene_type == "auto"){
      n_genes <- sapply(dna_segs, nrow)
      gene_type <- auto_gene_type(n_genes)
    }
    for (i in 1:n_dna_segs){
      dna_segs[[i]]$gene_type <- gene_type
    }
  }

  # deal with global color scheme: if no color defined or if override is
  # set, try to find a common numerical column in all comparisons
  if ((!any("col" %in% unlist(lapply(comparisons, names)))
           || override_color_schemes) && !is.null(comparisons)){
    # collect numerical columns
    num_cols <- lapply(comparisons, function(x) names(x)[sapply(x, is.numeric)])
    shared_num_cols <-
      names(which(table(unlist(num_cols)) == length(num_cols)))
    shared_num_cols <- shared_num_cols[!shared_num_cols %in%
                                       c("start1", "start2", "end1", "end2")]
    # global_color_scheme[1]: take color from?
    # take per_id if present, if not, evalue, else the first found in the
    # first comp
    if (global_color_scheme[1] == "auto"){
      names_comp_1 <- names(comparisons[[1]])
      global_color_scheme[1] <- if ("per_id" %in% shared_num_cols){
        "per_id"
      } else if ("e_value" %in% shared_num_cols) {
        "e_value"
      } else {
        names_comp_1[names_comp_1 %in% shared_num_cols][1]
      }
    } else if (! global_color_scheme[1] %in% shared_num_cols){
      stop("One or all columns don't have the indicated column for global color scheme")
    }
    # global_color_scheme[1]: incr/decr. Turn it to decreasing
    if (global_color_scheme[2] == "auto"){
      global_color_scheme[2] <-
        if (global_color_scheme[1] %in% c("mism", "gaps", "e_value"))
          TRUE else FALSE
    } else if (global_color_scheme[2] == "decreasing"){
      global_color_scheme[2] <- TRUE
    } else if (global_color_scheme[2] == "increasing"){
      global_color_scheme[2] <- FALSE
    } else {
      stop("Invalid value for global_color_scheme[2]")
    }
    # gather range of values from all comparisons
    range_col_from <-
      range(unlist(lapply(comparisons,
                          function(x) range(x[[global_color_scheme[1]]]))))
    # perform apply_color_scheme
    for (i in 1:n_comparisons){
      comparisons[[i]]$col <-
        apply_color_scheme(x=comparisons[[i]][[global_color_scheme[1]]],
                           direction=comparisons[[i]]$direction,
                           color_scheme=global_color_scheme[3],
                           decreasing=global_color_scheme[2],
                           rng=range_col_from,
                           transparency=as.numeric(global_color_scheme[4]))
    }
  }

  #----------------------------------------------------------------------------#
  # prepare plotting frame & filter objects 
  #----------------------------------------------------------------------------#
  # further calculations on xlims & gaps
  for (i in 1:n_dna_segs){
    xlims[[i]]$length <- xlims[[i]]$x1 - xlims[[i]]$x0
  }
  # default gap_length is a 20th of the max length
  if (!is.null(fixed_gap_length)) {
  	def_gap_length <- fixed_gap_length 
  } else {
  	def_gap_length <- max(sapply(xlims, function(x) sum(x$length)))*minimum_gap_size
  }
  unpadded_lengths <- sapply(xlims, function(x)
                             sum(x$length) + (nrow(x)-1)*def_gap_length)
  longest_seg <- which.max(unpadded_lengths)
  max_length <- unpadded_lengths[longest_seg]
  scale_unit <- diff(pretty(c(0, max_length), n=n_scale_ticks+2)[1:2])
  
  ### trim dna_segs ###
  # initiate new object: create subsegments by trimming original dna_seg
  dna_subsegs <- list()                    
  for (i in 1:n_dna_segs){
    n_subsegs <- nrow(xlims[[i]])
    dna_subsegs[[i]] <- list()
    for (j in 1:n_subsegs){
      dna_subsegs[[i]][[j]] <- trim.dna_seg(dna_segs[[i]], c(xlims[[i]]$x0[j],
                                                             xlims[[i]]$x1[j]))
    }
  }
  ### trim comparisons ###
  if (n_comparisons > 0){
    for (i in 1:n_comparisons){
      # trim from above first: make successive trims of the original comp
      comp1 <- comparisons[[i]][0,]
      for (j in 1:nrow(xlims[[i]])){
        comp1 <- rbind(comp1, trim.comparison(comparisons[[i]],
                                              xlim1=as.numeric(xlims[[i]][j,
                                                c("x0", "x1")])))
      }
      # trim from below then: trim from the previously obtained comp
      comp2 <- comparisons[[i]][0,]
      for (j in 1:nrow(xlims[[i+1]])){
        comp2 <- rbind(comp2, trim.comparison(comp1,
                                              xlim2=as.numeric(xlims[[i+1]][j,
                                                c("x0", "x1")])))
      }
      comparisons[[i]] <- comp2 
    }
  }

  ### trim extra_comparisons ###
  if (n_extra_comparisons > 0){
    for (i in 1:n_extra_comparisons){
      # trim from above first: make successive trims of the original comp
      comp1 <- extra_comparisons[[i]][0,]
      for (j in 1:nrow(xlims[[extra_comparisons_map[[i]][1]]])){
        comp1 <- rbind(comp1, trim.comparison(extra_comparisons[[i]],
                                              xlim1=as.numeric(xlims[[extra_comparisons_map[[i]][1]]][j,
                                                c("x0", "x1")])))
      }
      # trim from below then: trim from the previously obtained comp
      comp2 <- extra_comparisons[[i]][0,]
      for (j in 1:nrow(xlims[[extra_comparisons_map[[i]][2]]])){
        comp2 <- rbind(comp2, trim.comparison(comp1,
                                              xlim2=as.numeric(xlims[[extra_comparisons_map[[i]][2]]][j,
                                                c("x0", "x1")])))
      }
      extra_comparisons[[i]] <- comp2 
    }
  }

    ### calculate offsets ###
  if (is.null(offsets)){
    prel_offsets <- lapply(xlims, function(x)
                           c(0, rep(def_gap_length, nrow(x)-1)))
                           
    offsets <- minimize_comps(comparisons, xlims, unpadded_lengths,
                              prel_offsets, fixed_gap_length)
  } else {
    offsets <- as.list(offsets)
    for (i in 1:n_dna_segs){
      if (length(offsets[[i]]) == 1){
        offsets[[i]] <- c(offsets[[i]], rep(def_gap_length, nrow(xlims[[i]])-1))
      } else if (length(offsets[[i]]) != nrow(xlims[[i]])){
        stop("The length of each element of offsets should be either one or equal to the number of subsegments in the corresponding segment.")
      }
    }
  }
  
  # check if total length doesn't exceed max length
  if (limit_to_longest_dna_seg){
    for (i in 1:n_dna_segs){
      tot_length <- sum(c(xlims[[i]]$length, offsets[[i]]))
      if (tot_length > max_length){
        excess <- tot_length - max_length
        # reduce offsets from the end
        for (j in length(offsets[[i]]):1){
          # decrease offsets or set them to min_gap
          if ((offsets[[i]][j] - excess) < def_gap_length){
            excess <- excess - offsets[[i]][j] + def_gap_length
            offsets[[i]][j] <- def_gap_length
          } else {
            offsets[[i]][j] <- offsets[[i]][j] - excess
            break
          }
        }
      }
    }
  } else {
    # recalculate lengths
    padded_lengths <- sapply(xlims, function(x) sum(x$length)) +
      sapply(offsets, sum)
    max_length <- max(padded_lengths)
  }
  
  # recalculate comps coordinates
  if (n_comparisons > 0){
    for (i in 1:n_comparisons){
      comparisons[[i]] <- calc_comp_coor(offsets[[i]], xlims[[i]],
                                         comparisons[[i]], side=1)
      comparisons[[i]] <- calc_comp_coor(offsets[[i+1]], xlims[[i+1]],
                                         comparisons[[i]], side=2)
    }
  }
  
  # recalculate extra_comps coordinates
  if (n_extra_comparisons > 0){
    for (i in 1:n_extra_comparisons){
      extra_comparisons[[i]] <- calc_comp_coor(offsets[[extra_comparisons_map[[i]][1]]], xlims[[extra_comparisons_map[[i]][1]]],
                                         extra_comparisons[[i]], side=1)
      extra_comparisons[[i]] <- calc_comp_coor(offsets[[extra_comparisons_map[[i]][2]]], xlims[[extra_comparisons_map[[i]][2]]],
                                         extra_comparisons[[i]], side=2)
    }
  }

  # recalculate lengths
  padded_lengths <- sapply(xlims, function(x) sum(x$length)) +
    sapply(offsets, sum)
  max_length <- max(padded_lengths)
  
  #----------------------------------------------------------------------------#
  # collect grobs
  #----------------------------------------------------------------------------#
  ### collect dna_seg & dna_seg_scale grobs ###
  dna_seg_grobs <- list()
  dna_seg_scale_grobs <- list()
  for (i in 1:n_dna_segs){
    dna_seg_grobs[[i]] <- list()
    dna_seg_scale_grobs[[i]] <- list()
    for (j in 1:length(dna_subsegs[[i]])){
      # debug
      if (debug > 0 && debug < nrow(dna_subsegs[[i]][[j]]))
        dna_subsegs[[i]][[j]] <- dna_subsegs[[i]][[j]][1:debug,]
      # end debug
      dna_seg_grobs[[i]][[j]] <- dna_seg_grob(dna_subsegs[[i]][[j]],
                                            arrow_head_len, i)
      dna_seg_scale_grobs[[i]][[j]] <-
        if (dna_seg_scale[[i]])
          dna_seg_scale_grob(range=xlims[[i]][j,c("x0","x1")],
                             cex=scale_cex, unit=scale_unit, i=i, j=j)
        else NULL
    }
  }

  ### collect comparison grobs ###
  comparison_grobs <- list()
  if (n_comparisons > 0){
    for (i in 1:n_comparisons){
      # debug
      if (debug > 0 && debug < nrow(comparisons[[i]]))
        comparisons[[i]] <- comparisons[[i]][1:debug,]
      # end debug
      comparison_grobs[[i]] <- comparison_grob(comparisons[[i]], i)
    }
  }

  ### collect extra comparison grobs ###
  extra_comparison_grobs <- list()
  if (n_extra_comparisons > 0){
    for (i in 1:n_extra_comparisons){
      # debug
      if (debug > 0 && debug < nrow(extra_comparisons[[i]]))
        extra_comparisons[[i]] <- extra_comparisons[[i]][1:debug,]
      # end debug
      extra_comparison_grobs[[i]] <- comparison_grob(extra_comparisons[[i]], i)
    }
  }
  
  ### annotations ###
  if (!is.null(annotations)){
    annotation_grobs <- list()
    for (i in 1:n_dna_segs){
      if (is.null(annotations[[i]])){
        annotation_grobs[[i]] <- list(NULL)
      } else {
        annotation_grobs[[i]] <- list()
        for (j in 1:length(dna_subsegs[[i]])){
          annot <- trim.annotation(annotations[[i]],
                                   xlims[[i]][j, c("x0", "x1")])
          annotation_grobs[[i]][[j]] <- annotation_grob(annot,
                                                        annotation_cex)
        }
      }
    }
  }
  
  ### scale ###
  if (scale){
    scale_grob <- scale_grob(max_length)
    scale_h <- 1
  } else {
    scale_h <- 0
  }

  ### main title ###
  if (!is.null(main)){
    main_grob <- textGrob(x=main_x, label=main,
                          gp=gpar(cex=1.2), just=main_just)
    main_h <- 1.8
  } else {
    main_h <- 0
  }

  ### tree ###
  if (!is.null(tree)){
    # tree
    #phylog <- newick2phylog(tree)
    # check that a nice permutation is OK, return ys
    y <- permute_tree(tree, dna_seg_labels)
    # feed tree grob with permutation transformed as y coords
    tree_grob <- phylog_grob(tree, 1-((y-1)/(n_dna_segs-1)),
                             clabel.leaves=dna_seg_label_cex,
                             clabel.nodes=tree_branch_labels_cex)
    #tree_w <- unit(0.20, "npc")
    tree_w <- unit(0.1, "npc") + tree_grob$width
  } else if(!is.null(dna_seg_labels)){
    # just labels
    tree_grob <- dna_seg_label_grob(dna_seg_labels, cex=dna_seg_label_cex,
                                    col=dna_seg_label_col)
    tree_w <- tree_grob$width
  } else {
    # nothing
    tree_grob <- NULL
    tree_w <- unit(0, "npc")
  }
  if (!is.null(tree_width)) tree_w <- unit(tree_width, "inches")
  
  #----------------------------------------------------------------------------#
  # plotting
  #----------------------------------------------------------------------------#
  # overall frame
  if (plot_new) grid.newpage()
  pushViewport(viewport(width=unit(1, "npc")-unit(1, "lines"),
                        height=unit(1, "npc")-unit(1, "lines"),
                        name="oma"),
               viewport(layout=grid.layout(2, 1,
                          heights=unit(c(main_h, 1),
                            c("lines", "null"))),
                        name="oma_layout"))
  # main title
  if (!is.null(main)) {
    pushViewport(viewport(layout.pos.row=1, name="main"))
    grid.draw(main_grob)
    upViewport()
  }

  # frame: columns=tree,maps,legend rows=maps+tree+legend,scale 
  pushViewport(viewport(layout.pos.row=2,
                        layout=grid.layout(2, 3,
                          heights=unit(c(1, scale_h),
                            c("null", "lines")),
                          widths=unit.c(tree_w,
                            unit(c(1, 0), c("null", "null")))),
                        name="frame"))
  # scale
  if (scale) {
    pushViewport(viewport(layout.pos.row=2, layout.pos.col=2,
                          xscale=c(0, max_length), name="scale"))
    grid.draw(scale_grob)
    upViewport()
  }

  # tree or labels. Height is 1-3 lines because margin is 2 in plotarea,
  # and 1 to center to the middle of each dna_seg (1/2 line top and bottom)
  if (!is.null(tree_grob)){
    # make a supplementary 1/2 line margin if there is a scale in the last
    # dna_seg to get labels facing the text. Hack.
    bot_margin <- scale_cex * dna_seg_scale[[n_dna_segs]]
    # do the same if there is a annotation in the first dna_seg
    top_margin <- if (is.null(annotations[[1]])) 0 else annotation_height
    #bot_margin <- 1
    pushViewport(viewport(layout.pos.row=1, layout.pos.col=1,
                          name="tree_outer"),
                 viewport(width=unit(1, "npc")-unit(1, "lines"),
                          height=unit(1, "npc")-unit(1 + bot_margin +
                            top_margin, "lines"),
                          y=unit(1, "npc")-unit(0.5 + top_margin, "lines"),
                          just=c("centre", "top"),
                          name="tree"))
    grid.draw(tree_grob$grob)
    upViewport(2)    
  } 
  
  # plotting area
  pushViewport(viewport(layout.pos.row=1, layout.pos.col=2,
                        name="plotarea_outer"),
               viewport(width=unit(1, "npc")-unit(1, "lines"),
                        height=unit(1, "npc")-unit(0, "lines"),
                        name="plotarea", clip="on"))

  # map grid
  pushViewport(viewport(layout=grid.layout(n_rows, 1,
                          heights=dna_seg_heights), name="map"))
  ### comparisons ###
  if (n_comparisons > 0){
    for (i in 1:n_comparisons){
      pushViewport(viewport(layout.pos.row=2*i,
                            yscale=c(0,1),
                            xscale=c(0, max_length),
                            #clip="on",
                            name = paste("comparison", i, sep=".")))
      # draw comparison grobs
      grid.draw(comparison_grobs[[i]])
      upViewport() # pop comparisons[[i]] vp
    }
  }
  
    ### extra comparisons ###
  if (n_extra_comparisons > 0){
    for (i in 1:n_extra_comparisons){
      pushViewport(viewport(layout.pos.row=seq(from=2*(extra_comparisons_map[[i]][1]+dna_shift[[extra_comparisons_map[[i]][1]]]),to=2*(extra_comparisons_map[[i]][2]+dna_shift[[extra_comparisons_map[[i]][2]]]-1)),
                            yscale=c(0, 1),
                            xscale=c(0, max_length),
                            #clip="on",
                            name = paste("extra_comparison", i, sep=".")))
      # draw extra comparison grobs
      grid.draw(extra_comparison_grobs[[i]])
      upViewport() # pop extra_comparisons[[i]] vp
    }
  }
  
  ### dna_segs, annotations, scales ###
  for (i in 1:n_dna_segs){
    n_dna_subsegs <- length(dna_subsegs[[i]])
    n_cols <- n_dna_subsegs*2
    widths <- numeric(n_cols)
    widths[1:n_dna_subsegs*2] <- xlims[[i]]$length
    widths[1:n_dna_subsegs*2-1] <- offsets[[i]]
    widths_units <- unit(widths, rep("native", n_cols))
    heights <- unit(c(annot_h[i], 1, scale_cex*dna_seg_scale[i]),
                    c("lines", "null", "lines"))
    # push dna_seg grid (subsegments in cols, annotations, genes and
    # scales in rows)
    pushViewport(viewport(layout.pos.row=2*(i+dna_shift[[i]])-1,
                          layout=grid.layout(3, n_cols,
                            heights=heights,
                            widths=widths_units,
                            just=c("left", "centre")),
                          #clip="on",
                          xscale=c(0,max_length),
                          name=paste("scale_and_dna_seg", i, sep=".")))
    for (j in 1:n_dna_subsegs){
      # calculate xscale
      idx <- if (xlims[[i]]$strand[j] == 1) c("x0", "x1") else c("x1", "x0")
      xscale <- as.numeric(xlims[[i]][j,idx])
      # annotation
      if (!is.null(annotations[[i]])){
        pushViewport(viewport(layout.pos.row=1,
                              layout.pos.col=j*2,
                              yscale=c(0,1),
                              xscale=xscale,
                              just=c("left", "centre"),
                              name=paste("annotation", i, j, sep=".")))
        grid.draw(annotation_grobs[[i]][[j]])
        upViewport() # up annotation vp
      }
      # dna_seg_scale
      if (dna_seg_scale[i]){
        pushViewport(viewport(layout.pos.row=3,
                              layout.pos.col=j*2,
                              yscale=c(0,1),
                              xscale=xscale,
                              just=c("left", "centre"),
                              name=paste("dna_seg_scale", i, j, sep=".")))
        grid.draw(dna_seg_scale_grobs[[i]][[j]])
        upViewport() # up dna_seg_scale vp
      }
      # dna_seg itself
      pushViewport(viewport(layout.pos.row=2,
                            layout.pos.col=j*2,
                            yscale=c(0,1),
                            xscale=xscale,
                            just=c("left", "centre"),
                            name = paste("dna_seg", i, j, sep=".")))
      # draw segment line
      if (!dna_seg_line[i]=="FALSE"){
        grid.segments(x0=unit(xlims[[i]]$x0[j], "native"),
                      y0=unit(0.5, "native"),
                      x1=unit(xlims[[i]]$x1[j], "native"),
                      y1=unit(0.5, "native"),
                      name=paste("dna_seg_line", i, j, sep="."),
                      gp=gpar(col=dna_seg_line[i]))
      }
      #grid.xaxis()
      # draw dna_seg grobs
      grid.draw(dna_seg_grobs[[i]][[j]])
      upViewport() # up dna_seg
      # draw gap, but not at pos 1
      if (j > 1){
        pushViewport(viewport(layout.pos.row=2,
                              layout.pos.col=j*2-1,
                              yscale=c(0,1),
                              xscale=c(0, widths[2*j-1]),
                              just=c("centre", "centre"),
                              name=paste("gap", i, j, sep=".")))
        grid.draw(gap_grob(w=def_gap_length, m=widths[2*j-1]/2, i, j))
        upViewport() # up gap vp
      }
    }
    upViewport() # up scale_and_dna_seg vp
  }
  upViewport(2) # pop map viewports
  upViewport(2) # pop plotarea viewport
  upViewport(2) # pop frame+oma viewport
}
