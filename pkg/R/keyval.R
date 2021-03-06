# Copyright 2011 Revolution Analytics
#    
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, 
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

has.rows = function(x) !is.null(nrow(x))
all.have.rows = Curry(all.predicate, P = has.rows)

rmr.length = 
  function(x) if(has.rows(x)) nrow(x) else length(x)

rmr.equal = 
  function(xx, y) {
    if(rmr.length(xx) == 0) logical()
    else {
      if(is.atomic(xx) && !is.matrix(xx)) xx == y
      else {
        sapply(
          1:rmr.length(xx), 
          function(i) 
            isTRUE(
              all.equal(
                rmr.slice(xx,i), 
                y, 
                check.attributes=F)))}}}
    
length.keyval = 
  function(kv) 
    max(rmr.length(keys(kv)), 
        rmr.length(values(kv)))
  
keyval = 
  function(key, val = NULL) {
    if(missing(val)) list(key = NULL, val = key)
    else list(key = key, val = val)}

keys = function(kv) kv$key
values = function(kv) kv$val

is.keyval = 
  function(x) 
    is.list(x) && 
      length(x) == 2 && 
      !is.null(names(x)) && 
      all(names(x) == qw(key, val))

as.keyval = 
  function(x) {
    if(is.keyval(x)) x
    else keyval(x)}

rmr.slice = 
  function(x, r) {
    if(has.rows(x))
      x[r, , drop = FALSE]
    else
      x[r]}

rmr.recycle = 
  function(x,y) {
    lx = rmr.length(x)
    ly = rmr.length(y)
    if(lx == ly) x
    else {
      if(min(lx,ly) == 0){
        rmr.str(lx)
        rmr.str(ly)
        stop("Can't recycle 0-length argument")}
      else
        rmr.slice(
          c.or.rbind(
            rep(list(x),
                ceiling(ly/lx))),
          1:max(ly, lx))}}

recycle.keyval =
  function(kv) {
    k = keys(kv)
    v = values(kv)
    if(is.null(k) || (rmr.length(k) == rmr.length(v)))
      kv
    else
      keyval(
        rmr.recycle(k, v),
        rmr.recycle(v, k))}

slice.keyval = 
  function(kv, r) {
    kv = recycle.keyval(kv)
    keyval(rmr.slice(keys(kv), r),
           rmr.slice(values(kv), r))}

c.or.rbind = 
  Make.single.or.multi.arg(
    function(x) {
      if(is.null(x))
        NULL 
      else {
        if(length(x) == 0) 
          list()
        else { 
          if(any(sapply(x, has.rows))) { 
            if(any(sapply(x, is.data.frame))){
              x = x[!sapply(x, is.null)]
              do.call(rbind.fill,x)}
            else
              do.call(rbind, x)}
          else
            do.call(c,x)}}})

c.keyval = 
  Make.single.or.multi.arg(
  function(kvs) {
    zero.length = as.logical(sapply(kvs, function(kv) length.keyval(kv) == 0))
    null.keys = as.logical(sapply(kvs, function(kv) is.null(keys(kv))))
    if(!(all(null.keys | zero.length) || !any(null.keys & !zero.length))) {
      rmr.str(kvs)
      stop("can't mix NULL and not NULL key keyval pairs")}
    kvs = lapply(kvs, recycle.keyval)
    vv = lapply(kvs, values)
    kk = lapply(kvs, keys)
    keyval(c.or.rbind(kk), c.or.rbind(vv))})
  
rmr.split = 
  function(x, ind) {
    if(rmr.length(ind) == 1)
      list(x)
    else {
      spl = if(has.rows(x)) split.data.frame else split
      spl(x,ind, drop = TRUE)}}

key.normalize= function(k) {
  k = rmr.slice(k, 1)
  if (is.data.frame(k) || is.matrix(k))
    rownames(k) = NULL
  k}

split.keyval = function(kv, size) {
  k = keys(kv)
  v = values(kv)
  if(is.null(k)) {
    k =  ceiling(1:rmr.length(v)/size)
    recycle.keyval(
      keyval(list(NULL),
             unname(rmr.split(v, k))))}
  else {
    kv = recycle.keyval(kv)
    k = keys(kv)
    v = values(kv)
    ind = {
      if(is.list(k) && !is.data.frame(k)) 
        sapply(k, digest)
      else {
        if(is.matrix(k))
          as.data.frame(k)
        else {
          if(is.raw(k))
            as.integer(k)
          else
            k}}}
    x = k 
    if(has.rows(x)) 
      rownames(x) = NULL
    else
      names(x) = NULL
    x = unname(rmr.split(x, ind))
    if ((rmr.length(x) != rmr.length(k)) || 
          is.data.frame(k))
      x = lapply(x, key.normalize)
    keyval(x, unname(rmr.split(v, ind)))}}

unsplit.keyval = function(kv) {
  c.keyval(mapply(keyval, keys(kv), values(kv), SIMPLIFY = FALSE))}

apply.keyval = 
  function(
    kv, 
    FUN, 
    split.size = 
      stop("Must specify key when using keyval in map and combine functions")) {
    k = keys(kv)
    kvs = split.keyval(kv, split.size)
    if(is.null(k)) 
      lapply(values(kvs), function(v) FUN(NULL,v))
    else
      mapply(FUN, keys(kvs), values(kvs), SIMPLIFY = FALSE)}
