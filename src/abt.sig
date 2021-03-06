signature ABT =
sig
  structure Variable : VARIABLE
  structure Operator : OPERATOR

  type variable = Variable.t
  type operator = Operator.t
  type sort = Operator.Arity.Sort.t
  type valence = Operator.Arity.Valence.t
  type 'a spine = 'a Operator.Arity.Valence.Spine.t

  type abt
  include EQ where type t = abt

  (* Patterns for abstract binding trees. *)
  datatype 'a view =
      ` of variable
    | $ of operator * 'a spine
    | \ of variable spine * 'a

  structure ViewFunctor : FUNCTOR where type 'a t = 'a view

  (* Construct an abt from a view by checking it against a valence. *)
  val check : abt view * valence -> abt

  (* Pattern match on an abt and its valence. *)
  val infer : abt -> valence * abt view
end
