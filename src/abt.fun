functor Abt (structure Variable : VARIABLE and Operator : OPERATOR) : ABT =
struct

  structure Variable = Variable and Operator = Operator and Arity = Operator.Arity
  structure Sort = Arity.Sort and Valence = Arity.Valence
  structure Spine = Valence.Spine

  type variable = Variable.t
  type operator = Operator.t
  type sort = Sort.t
  type valence = Valence.t

  type 'a spine = 'a Spine.t

  datatype abt =
      FV of variable * sort
    | BV of Coord.t * sort
    | ABS of (variable * sort) spine * abt
    | APP of operator * abt spine

  datatype 'a view =
      ` of variable
    | $ of operator * 'a spine
    | \ of variable spine * 'a

  infixr 5 \
  infix 5 $

  structure ViewFunctor =
  struct
    type 'a t = 'a view
    fun map f e =
      case e of
          ` x => ` x
       | x \ e => x \ f e
       | theta $ es => theta $ Spine.Functor.map f es
  end


  fun imprisonVariable v (coord, e) =
    case e of
         FV (v', sigma) =>
           if Variable.eq (v, v') then BV (coord, sigma) else e
       | BV _ => e
       | ABS (xs, e') => ABS (xs, imprisonVariable v (Coord.shiftRight coord, e'))
       | APP (theta, es) =>
           APP (theta, Spine.Functor.map (fn e => imprisonVariable v (coord, e)) es)

  fun liberateVariable v (coord, e) =
    case e of
         FV _ => e
       | BV (ann as (coord', sigma)) =>
           if Coord.eq (coord, coord') then FV (v, sigma) else BV ann
       | ABS (xs, e) => ABS (xs, liberateVariable v (Coord.shiftRight coord, e))
       | APP (theta, es) =>
           APP (theta, Spine.Functor.map (fn e => liberateVariable v (coord, e)) es)

  local
    structure ShiftFunCat : CATEGORY =
    struct
      type ('a, 'b) hom = (Coord.t * 'a -> 'b)
      fun id (_, x) = x
      fun comp (f, g) (coord, a) = f (coord, g (Coord.shiftDown coord, a))
    end

    structure ShiftFoldMap =
      CategoryFoldMap
        (structure C = ShiftFunCat
         structure F = Spine.Foldable)
  in
    fun imprisonVariables vs t =
      ShiftFoldMap.foldMap imprisonVariable vs (Coord.origin, t)

    fun liberateVariables vs t =
      ShiftFoldMap.foldMap liberateVariable vs (Coord.origin, t)
  end

  fun assert msg b =
    if b then () else raise Fail msg

  fun assertSortEq (sigma, tau) =
    assert
      ("expected " ^ Sort.toString sigma ^ " == " ^ Sort.toString tau)
      (Sort.eq (sigma, tau))

  fun assertValenceEq (v1, v2) =
    assert
      ("expected " ^ Valence.toString v1 ^ " == " ^ Valence.toString v2)
      (Valence.eq (v1, v2))

  fun check (e, valence as (sorts, sigma)) =
    case e of
         `x =>
           let
             val () = assert "sorts not empty" (Spine.isEmpty sorts)
           in
             FV (x, sigma)
           end
       | xs \ e =>
           let
             val ((_, tau), _) = infer e
             val () = assertSortEq (sigma, tau)
           in
             ABS (Spine.Pair.zipEq (xs, sorts), imprisonVariables xs e)
           end
       | theta $ es =>
           let
             val () = assert "sorts not empty" (Spine.isEmpty sorts)
             val (valences, tau) = Operator.arity theta
             val () = assertSortEq (sigma, tau)
             fun chkInf (e, valence) =
               let
                 val (valence', _) = infer e
                 val () = assertValenceEq (valence, valence')
               in
                 e
               end
           in
             APP (theta, Spine.Pair.mapEq chkInf (es, valences))
           end

  and infer (FV (v, sigma)) = ((Spine.empty (), sigma), ` v)
    | infer (BV _) = raise Fail "Impossible: unexpected bound variable"
    | infer (ABS (bindings, e)) =
      let
        val xs = Spine.Functor.map (Variable.clone o #1) bindings
        val (sorts, tau) = inferValence e
        val () = assert "sorts not empty" (Spine.isEmpty sorts)
        val valence = (Spine.Functor.map #2 bindings, tau)
      in
        (valence, xs \ liberateVariables xs e)
      end
    | infer (APP (theta, es)) =
      let
        val (_, tau) = Operator.arity theta
      in
        ((Spine.empty (), tau), theta $ es)
      end

  and inferValence (FV (v, sigma)) = (Spine.empty (), sigma)
    | inferValence (BV (i, sigma)) = (Spine.empty (), sigma)
    | inferValence (ABS (bindings, e)) =
      let
        val (_, sigma) = inferValence e
        val sorts = Spine.Functor.map #2 bindings
      in
        (sorts, sigma)
      end
    | inferValence (APP (theta, es)) =
      let
        val (_, sigma) = Operator.arity theta
      in
        (Spine.empty (), sigma)
      end

  structure Eq : EQ =
  struct
    type t = abt
    fun eq (FV (v, _), FV (v', _)) = Variable.eq (v, v')
      | eq (BV (i, _), BV (j, _)) = Coord.eq (i, j)
      | eq (ABS (_, e), ABS (_, e')) = eq (e, e')
      | eq (APP (theta, es), APP (theta', es')) =
          Operator.eq (theta, theta') andalso Spine.Pair.allEq eq (es, es')
      | eq _ = false
  end

  open Eq
end
