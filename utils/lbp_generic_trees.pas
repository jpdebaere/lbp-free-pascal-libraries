{* ***************************************************************************

Copyright (c) 2017 by Lloyd B. Park
Copyright (c) 2008 by Mattias Gaertner

AVL (Average Level) tree which uses generics
The AVL Tree is my attempt to make a generic version of Mattias Gaertner's
tAVLTree in the AVL_Tree unit included with Free Pascal.  Since I had written
my own AVL tree very shortly before Mattias' was released, I combined features
of both into this one. 


This file is part of Lloyd's Free Pascal Libraries (LFPL).

    LFPL is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as 
    published by the Free Software Foundation, either version 2.1 of the 
    License, or (at your option) any later version with the following 
    modification:

    As a special exception, the copyright holders of this library 
    give you permission to link this library with independent modules
    to produce an executable, regardless of the license terms of these
    independent modules, and to copy and distribute the resulting 
    executable under terms of your choice, provided that you also meet,
    for each linked independent module, the terms and conditions of 
    the license of that module. An independent module is a module which
    is not derived from or based on this library. If you modify this
    library, you may extend this exception to your version of the 
    library, but you are not obligated to do so. If you do not wish to
    do so, delete this exception statement from your version.

    LFPL is distributed in the hope that it will be useful,but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General 
    Public License for more details.

    You should have received a copy of the GNU Lesser General Public 
    License along with LFPL.  If not, see <http://www.gnu.org/licenses/>.

*************************************************************************** *}

unit lbp_generic_trees;

interface

{$include lbp_standard_modes.inc}
//{$V-}    //Added by LP because it says so below
//{$R-}    //Range checking off
//{$S-}    //Stack checking off
//{$I-}    //I/O checking off
{$LONGSTRINGS ON}    // Non-sized Strings are ANSI strings

uses
   sysutils,      // Exceptions
   lbp_types,     // lbp_excpetion
   lbp_utils,     // PadLeft() - Only used to print debug information
   lbp_generic_lists,
   typinfo;
//   lbp_vararray;  // Int64SortElement

// *******************************************************
// tObject.ToString() - returns class name by default    *
// *******************************************************

 

// ************************************************************************

type
   lbpContainerException = class( lbp_exception);

// ************************************************************************
// * tgAvlTree
// ************************************************************************

type
   generic tgAvlTree< V: tObject> = class( tObject)
      private type
      // ---------------------------------------------------------------
         tNode = class( tObject)
            protected
               Parent:      tNode;
               LeftChild:   tNode;
               RightChild:  tNode;
               Balance:     integer;
               Value:       V;
            public
               constructor  Create( iValue: V);
               procedure    Clear;
               function     TreeDepth(): integer; // longest WAY down. e.g. only one tNode => 0 !
               function     First():    tNode;
               function     Last():     tNode;
               function     Next():     tNode;
               function     Previous(): tNode;
            end; // tNode class
      // ---------------------------------------------------------------
      private type
         tEnumerator = class( tObject)
            private
               Tree:    tgAvlTree;
               Node:    tNode;
            public
               constructor Create( iTree: tgAvlTree);
               function    MoveNext: Boolean;
               property    Current: V read Node.Value;
            end; // enumerator class
      // ---------------------------------------------------------------
      private type
         tReverseEnumerator = class( tObject)
            private
               Tree:    tgAvlTree;
               Node:    tNode;
            public
               constructor Create( iTree: tgAvlTree);
               function    MoveNext: Boolean;
               function    GetEnumerator(): tReverseEnumerator;
               property    Current: V read Node.Value;
            end; // enumerator class
      // ---------------------------------------------------------------


      public
         type
            tCompareFunction = function( const iValue1, iValue2: V): Integer;
            tNodeToStringFunction = function( const iValue: V): string;  
      private
         MyRoot:          tNode;
         DuplicateOK:     boolean;
         MyForward:       boolean; // Iterator direction
         CurrentNode:     tNode;
         MyCount:         integer;
         MyName:          string;
         MyCompare:       tCompareFunction;
         MyNodeToString:  tNodeToStringFunction;
      public
         Constructor Create( iCompare:        tCompareFunction;
                             iAllowDuplicates: boolean = false);
         Destructor  Destroy(); override;
         procedure   RemoveAll( DestroyElements: boolean = false); virtual;
         procedure   Add( iValue: V); virtual;
         procedure   RemoveCurrent(); virtual; // Remove the Current Node from the tree
         procedure   Remove( iValue: V);  virtual; // Remove the node which contains T
         function    Find( iValue: V): boolean; virtual;
         procedure   StartEnumeration(); virtual;
         function    Previous():  boolean; virtual;
         function    Next():      boolean; virtual;
         function    Value(): V; virtual;
         function    GetEnumerator(): tEnumerator;
         function    Reverse(): tReverseEnumerator;
         procedure   Dump( N:       tNode = nil; 
                           Prefix:  string = ''); virtual;  // Debug code
      private
         function    FindNode( iValue: V): tNode; virtual;
         procedure   RemoveNode( N: tNode);  virtual; // Remove the passed node
         function    IsEmpty():  boolean; virtual;
         procedure   RemoveSubtree( StRoot: tNode; DestroyElements: boolean); virtual;
         function    FindInsertPosition( iValue: V): tNode; virtual;
         procedure   RebalanceAfterAdd( N: tNode); virtual;
         procedure   RebalanceAfterRemove( N: tNode); virtual;
      public
         property    AllowDuplicates: boolean
                                read DuplicateOK write DuplicateOK;
         property    Empty: boolean read IsEmpty write RemoveAll;
         property    Count: integer read MyCount;
         property    Root:  tNode read MyRoot;
         property    Name:  string  read MyName write MyName;
         property    Compare: tCompareFunction read MyCompare write MyCompare;
         property    NodeToString:  tNodeToStringFunction read MyNodeToString write MyNodeToString;
      end; // tgAvlTree


// ************************************************************************

implementation

// ========================================================================
// = tNode generic class
// ========================================================================
// ************************************************************************
// * Create() - constructor
// ************************************************************************
constructor tgAvlTree.tNode.Create( iValue: V);
   begin
      Parent:= nil;
      LeftChild:= nil;
      RightChild:= nil;
      Balance:= 0;
      Value:= iValue;
   end;

// ************************************************************************
// * Clear() - Zero out the fields 
// ************************************************************************

procedure tgAvlTree.tNode.Clear();
   begin
      Parent:= nil;
      LeftChild:= nil;
      RightChild:= nil;
      Balance:= 0;
      Value:= nil;
   end;

// ************************************************************************
// * TreeDepth() - Returns the depth of this node.
// ************************************************************************

function tgAvlTree.tNode.TreeDepth(): integer;
// longest WAY down. e.g. only one node => 0 !
var 
   LeftDepth:  integer;
   RightDepth: integer;
begin
  if LeftChild<>nil then begin
    LeftDepth:=LeftChild.TreeDepth+1
  end else begin
    LeftDepth:=0;
  end;

  if RightChild<>nil then begin
    RightDepth:=RightChild.TreeDepth+1
  end else begin
    RightDepth:=0;
  end;
  
  if LeftDepth>RightDepth then
    Result:=LeftDepth
  else
    Result:=RightDepth;
end; // TreeDepth


// ************************************************************************
// * First() - Return the lowest value (leftmost) node of this node's 
// *           subtree. 
// ************************************************************************

function tgAvlTree.tNode.First(): tNode;
   begin
      result:= Self;
      while( result.LeftChild <> nil) do result:= result.LeftChild;
   end;


// ************************************************************************
// * Last() - Return the lowest value (rightmost) node of this node's 
// *          subtree. 
// ************************************************************************

function tgAvlTree.tNode.Last(): tNode;
   begin
      result:= Self;
      while( result.RightChild <> nil) do result:= result.RightChild;
   end;


// ************************************************************************
// * Next() - Return the next node in the tree
// ************************************************************************

function tgAvlTree.tNode.Next(): tNode;
   var
      PreviousNode: tNode;
   begin
      result:= Self;
      // Do we need to head toward our parent?
      if( result.RightChild = nil) then begin
         // Try from our parent
         repeat
            PreviousNode:= result;
            result:= result.Parent;
         until( (result = nil) or (result.LeftChild = PreviousNode)) 

      end else begin
         // try our RightChild child
         result:= result.RightChild;
         while( result.LeftChild <> nil) do result:= result.LeftChild;
      end;     
   end; // Next()


// ************************************************************************
// * Previous() - Return the previous node in the tree
// ************************************************************************

function tgAvlTree.tNode.Previous(): tNode;
   var
      PreviousNode: tNode;
   begin
      result:= Self;
      // Do we need to head toward our parent?
      if( result.LeftChild = nil) then begin
         // Try from our parent
         repeat
            PreviousNode:= result;
            result:= result.Parent;
         until( (result = nil) or (result.RightChild = PreviousNode)) 

      end else begin
         // try our RightChild child
         result:= result.LeftChild;
         while( result.RightChild <> nil) do result:= result.RightChild;
      end;     
   end; // Previous()



// ========================================================================
// = tEnumerator class
// ========================================================================
// ************************************************************************
// * Create() - constructor
// ************************************************************************

constructor tgAvlTree.tEnumerator.Create( iTree: tgAvlTree);
   begin
      Tree:=    iTree;
      Node:=    nil;    
   end; // Create()


// ************************************************************************
// * MoveNext()
// ************************************************************************

function tgAvlTree.tEnumerator.MoveNext(): boolean;
   begin
      // Starting a new iteration?
      if( (Node = nil) and (Tree.MyRoot <> nil)) then begin
         Node:= Tree.MyRoot.First;
      end else if( Node <> nil) then begin
         Node:= Node.Next;
      end;

      result:= (Node <> nil)
   end; // MoveNext()



// ========================================================================
// = tReverseEnumerator class
// ========================================================================
// ************************************************************************
// * Create() - constructor
// ************************************************************************

constructor tgAvlTree.tReverseEnumerator.Create( iTree: tgAvlTree);
   begin
      Tree:=    iTree;
      Node:=    nil;    
   end; // Create()


// ************************************************************************
// * MoveNext()
// ************************************************************************

function tgAvlTree.tReverseEnumerator.MoveNext(): boolean;
   begin
      // Starting a new iteration?
      if( (Node = nil) and (Tree.MyRoot <> nil)) then begin
         Node:= Tree.MyRoot.Last;
      end else if( Node <> nil) then begin
         Node:= Node.Previous;
      end;

      result:= (Node <> nil)
   end; // MoveNext()


// ************************************************************************
// * GenEnumerator()
// ************************************************************************

function tgAvlTree.tReverseEnumerator.GetEnumerator: tReverseEnumerator;
   begin
      result:= self;  
   end; // GetEnumerator()



// ========================================================================
// = tgAvlTree generic class
// ========================================================================
// ************************************************************************
// * Create() - Constructors
// ************************************************************************

constructor tgAvlTree.Create( iCompare:     tCompareFunction;
                                  iAllowDuplicates: boolean = false);
   begin
      inherited Create;
      MyRoot:= nil;
      MyCompare:= iCompare;
      MyNodeToString:= nil;
      DuplicateOK:= iAllowDuplicates;
      MyForward:= true;
      CurrentNode:= nil;
      MyName:= '';
      MyCount:= 0;
   end; // Create()


// ************************************************************************
// * Destroy() - Destructor
// ************************************************************************

Destructor tgAvlTree.Destroy();
   begin
      RemoveAll;
      inherited Destroy();
   end;


// ************************************************************************
// * RemoveAll() - Remove all the elements from the tree and optionally 
// *               Destroy() the elements.
// ************************************************************************

procedure tgAvlTree.RemoveAll( DestroyElements: boolean);
   begin
      if( MyRoot <> nil) then RemoveSubtree( MyRoot, DestroyElements);
      MyRoot:= nil;
   end; // RemoveAll()


// ************************************************************************
// * FindInsertPosition() - Find the node to which this new iValue will be 
// *                        a child.
// ************************************************************************

function tgAvlTree.FindInsertPosition( iValue: V): tNode;
   var 
      Comp: integer;
   begin
      Result:= MyRoot;
      while( Result <> nil) do begin
         Comp:= MyCompare( iValue, Result.Value);
         if Comp < 0 then begin
            if Result.LeftChild <> nil then Result:=Result.LeftChild
            else exit;
         end else begin
            if Result.RightChild <> nil then Result:=Result.RightChild
            else exit;
         end;
      end; // while
   end; //FindInsertPosition()


// ************************************************************************
// * Add() - Add an element to the tree
// ************************************************************************

procedure tgAvlTree.Add( iValue: V);
   var 
      InsertPos:   tNode;
      Comp:        integer;
      NewNode:     tNode;
   begin
      NewNode:= tNode.create( iValue);
      inc( MyCount);
      if MyRoot <> nil then begin
         InsertPos:= FindInsertPosition( iValue);
         Comp:= MyCompare( iValue, InsertPos.Value);
         NewNode.Parent:= InsertPos;
         if( Comp < 0) then begin
            // insert to the left
            InsertPos.LeftChild:= NewNode;
         end else begin
            // Check for unallowed duplicate
            if( (Comp = 0) and DuplicateOK) then begin
              NewNode.Destroy(); // Clean up
              raise lbpContainerException.Create( 'Duplicate key values are not allowed in this AVL Tree!');
            end;
            // insert to the right
            InsertPos.RightChild:= NewNode;
         end;
         RebalanceAfterAdd( NewNode);
      end else begin
         MyRoot:=NewNode;
      end;
   end; // TgAvlTree.Add()


// ************************************************************************
// * Remove() - Remove the current node from the tree
// ************************************************************************

procedure tgAvlTree.RemoveCurrent();
   begin
      if( CurrentNode = nil) then begin
         raise lbpContainerException.Create( 'Attempting to delete the current node from the tree when it is empty!');
      end;
      RemoveNode( CurrentNode);
      CurrentNode:=nil;
   end; // Remove()


// ************************************************************************
// * Remove() - Find a node which contains iValue and remove it.
// ************************************************************************

procedure tgAvlTree.Remove( iValue: V);
   var
      N: tNode;
   begin
      CurrentNode:= nil;
      N:= FindNode( iValue);
      if( N = nil) then begin
         raise lbpContainerException.Create( 'The passed Value was not found in the tree.');
      end;
      RemoveNode( N);
   end; // Remove()


// ************************************************************************
// * Find() - returns true if the passed value is found in the tree
// *          Call Value() to get the found value.
// ************************************************************************

function tgAvlTree.Find( iValue: V): boolean;
   begin
      CurrentNode:= FindNode( iValue);
      result:= (CurrentNode <> nil);
   end; // Find()


// ************************************************************************
// * StartEnumeration() - Prepare for a new enmeration.
// ************************************************************************

procedure tgAvlTree.StartEnumeration();
   begin
      CurrentNode:= nil;
   end; /// StartEnumeration()


// ************************************************************************
// * Previous() - Move to the previous node in the tree and return true if
// *              successful.
// ************************************************************************

function tgAvlTree.Previous(): boolean;
   begin
      // Starting a new iteration?
      if( (CurrentNode = nil) and (MyRoot <> nil)) then begin
         CurrentNode:= MyRoot.Last;
      end else if( CurrentNode <> nil) then begin
         CurrentNode:= CurrentNode.Previous;
      end;

      result:= (CurrentNode <> nil)
   end; /// Previous()


// ************************************************************************
// * Next()) - Move to the Next node in the tree and return true if successful.
// ************************************************************************

function tgAvlTree.Next(): boolean;
   begin
      // Starting a new iteration?
      if( (CurrentNode = nil) and (MyRoot <> nil)) then begin
         CurrentNode:= MyRoot.First;
      end else if( CurrentNode <> nil) then begin
         CurrentNode:= CurrentNode.Next;
      end;

      result:= (CurrentNode <> nil)
   end; /// Next()


// ************************************************************************
// * Value() - Return the value of the current node in the tree.True
// ************************************************************************

function tgAvlTree.Value(): V;
   begin
      // Starting a new iteration?
      if( CurrentNode = nil) then begin
         raise lbpContainerException.Create( 'Attempt to access the current tree node''s value outside of an enumeration.');
      end;
      result:= CurrentNode.Value;
   end; /// Value()


// ************************************************************************
// * GetEnumerator()
// ************************************************************************

function tgAvlTree.GetEnumerator(): tEnumerator;
   begin
      result:= tEnumerator.Create( Self);
   end; // GetEnumerator()


// ************************************************************************
// * Reverse() - Gets the reverse order enumerator
// ************************************************************************

function tgAvlTree.Reverse(): tReverseEnumerator;
   begin
      result:= tReverseEnumerator.Create( Self);
   end; // Reverse()


// ************************************************************************
// * DumpNOdes
// ************************************************************************

//  d - b - a
//  |    \- c
//   \- f - e
//       \- g

procedure tgAvlTree.Dump( N:       tNode = nil;
                          Prefix:  string       = ''); 
   var
      Temp: string;
   begin
      if( MyNodeToString = nil) then 
         writeln( 'The tree can not be dumped because ''NodeToString'' has not be set!');

      // Take care of the start condition and the empty cases
      if( N = nil) then begin
         if( MyRoot = nil) then exit;
         N:= MyRoot;
      end;

      // Convert the value to something printable
      Temp:= MyNodeToString( N.Value);
      if( Length( Temp) > 4) then SetLength( Temp, 4);
      PadLeft( Temp, 4);

      // Print N's value
      write( Temp);

      // Process the Left Branch
      if( N.LeftChild = nil) then begin
         writeln;
      end else begin
         write( ' -> ');
         Dump( N.LeftChild, Prefix + '   |    ');
      end;

      // Process the Right Branch
      if( N.RightChild <> nil) then begin
         write( Prefix, '    \-> ');
         Dump( N.RightChild, Prefix + '        ');
      end;
   end; // Dump


// ************************************************************************
// * FindNode() - Returns a node which contains iValue.  Return nil if no
// *              node is found.  Used internally.
// ************************************************************************

function tgAvlTree.FindNode( iValue: V): tNode;
   var 
      Comp: integer;
   begin
      Result:=MyRoot;
      while( Result <> nil) do begin
        Comp:= MyCompare( iValue, Result.Value);
        if Comp=0 then exit;
        if Comp<0 then begin
            Result:=Result.LeftChild;
         end else begin
            Result:=Result.RightChild;
         end;
      end; // while
   end; // FindNode()


// ************************************************************************
// * RemoveNode() - Remove the passed node from the tree
// ************************************************************************

procedure tgAvlTree.RemoveNode( N: tNode);
   var 
      OldParent:     tNode;
      OldLeft:       tNode;
      OldRight:      tNode;
      Successor:     tNode;
      OldSuccParent: tNode;
      OldSuccLeft:   tNode;
      OldSuccRight:  tNode;
      OldBalance:    integer;
   begin
   OldParent:=N.Parent;
   OldBalance:=N.Balance;
   N.Parent:=nil;
   N.Balance:=0;
   if( (N.LeftChild = nil) and (N.RightChild = nil)) then begin
      // Node is Leaf (no children)
      if( OldParent <> nil) then begin
         // Node has parent
         if( OldParent.LeftChild = N) then begin
            // Node is left Son of OldParent
            OldParent.LeftChild:= nil;
            Inc( OldParent.Balance);
         end else begin
            // Node is right Son of OldParent
            OldParent.RightChild:= nil;
            Dec( OldParent.Balance);
         end;
         RebalanceAfterRemove( OldParent);
      end else begin
         // Node is the only node of tree
         MyRoot:= nil;
      end;
      dec( MyCount);
      N.Destroy;
      exit;
   end;
   if( N.RightChild = nil) then begin
      // Left is only son
      // and because DelNode is AVL, Right has no childrens
      // replace DelNode with Left
      OldLeft:= N.LeftChild;
      N.LeftChild:= nil;
      OldLeft.Parent:= OldParent;
      if( OldParent <> nil) then begin
         if( OldParent.LeftChild = N) then begin
            OldParent.LeftChild:= OldLeft;
            Inc( OldParent.Balance);
         end else begin
            OldParent.RightChild:= OldLeft;
            Dec( OldParent.Balance);
         end;
         RebalanceAfterRemove( OldParent);
      end else begin
         MyRoot:= OldLeft;
      end;
      dec( MyCount);
      N.Destroy;
      exit;
   end;
   if( N.LeftChild = nil) then begin
      // Right is only son
      // and because DelNode is AVL, Left has no childrens
      // replace DelNode with Right
      OldRight:= N.RightChild;
      N.RightChild:= nil;
      OldRight.Parent:= OldParent;
      if( OldParent <> nil) then begin
         if( OldParent.LeftChild = N) then begin
            OldParent.LeftChild:= OldRight;
            Inc( OldParent.Balance);
         end else begin
            OldParent.RightChild:= OldRight;
            Dec( OldParent.Balance);
         end;
         RebalanceAfterRemove( OldParent);
      end else begin
         MyRoot:=OldRight;
      end;
      dec( MyCount);
      N.Destroy;
      exit;
   end;
   // DelNode has both: Left and Right
   // Replace N with symmetric Successor
   Successor:= N.Next();
   OldLeft:= N.LeftChild;
   OldRight:= N.RightChild;
   OldSuccParent:= Successor.Parent;
   OldSuccLeft:= Successor.LeftChild;
   OldSuccRight:= Successor.RightChild;
   N.Balance:= Successor.Balance;
   Successor.Balance:= OldBalance;
   if( OldSuccParent <> N) then begin
      // at least one node between N and Successor
      N.Parent:= Successor.Parent;
      if( OldSuccParent.LeftChild = Successor) then
         OldSuccParent.LeftChild:= N
      else
         OldSuccParent.RightChild:= N;
      Successor.RightChild:= OldRight;
      OldRight.Parent:= Successor;
   end else begin
      // Successor is right son of N
      N.Parent:= Successor;
      Successor.RightChild:= N;
   end;
   Successor.LeftChild:= OldLeft;
   if( OldLeft <> nil) then
      OldLeft.Parent:= Successor;
   Successor.Parent:= OldParent;
   N.LeftChild:= OldSuccLeft;
   if( N.LeftChild <> nil) then
      N.LeftChild.Parent:= N;
   N.RightChild:= OldSuccRight;
   if( N.RightChild <> nil) then
      N.RightChild.Parent:= N;
   if( OldParent <> nil) then begin
      if( OldParent.LeftChild = N) then
         OldParent.LeftChild:= Successor
      else
         OldParent.RightChild:= Successor;
   end else
      MyRoot:= Successor;
   // delete Node as usual
   RemoveNode( N);
end; // RemoveNode()


// ************************************************************************
// * IsEmpty() - Returns true if the tree is empty.
// ************************************************************************

function tgAvlTree.IsEmpty(): V;
   begin
      result:= (MyCount = 0);
   end; // First()


// ************************************************************************
// * RemoveSubtree() - Helper for RemoveAll
// ************************************************************************

procedure tgAvlTree.RemoveSubtree( StRoot: tNode; DestroyElements: boolean);
   begin
      if( StRoot.LeftChild <> nil) then begin
         RemoveSubtree( StRoot.LeftChild, DestroyElements);
      end;
      if( StRoot.RightChild <> nil) then begin 
         RemoveSubtree( StRoot.RightChild, DestroyElements);
      end;
      if( DestroyElements) then StRoot.Value.Destroy;
      StRoot.Destroy;
   end; // RemoveSubtree()


// ************************************************************************
// * RebalanceAfterAdd() - Rebalance the tree after an Add()
// ************************************************************************

procedure tgAvlTree.RebalanceAfterAdd( N: tNode);
   var 
      OldParent:       tNode;
      OldParentParent: tNode;
      OldRight:        tNode;
      OldRightLeft:    tNode;
      OldRightRight:   tNode;
      OldLeft:         tNode;
      OldLeftLeft:     tNode;
      OldLeftRight:    tNode;
   begin
      OldParent:= N.Parent;
      if( OldParent = nil) then exit;
      if( OldParent.LeftChild = N) then begin
         // Node is left son
         dec( OldParent.Balance);
         if( OldParent.Balance = 0) then exit;
         if( OldParent.Balance = -1) then begin
            RebalanceAfterAdd( OldParent);
            exit;
         end;
         // OldParent.Balance=-2
         if( N.Balance = -1) then begin
            // rotate
            OldRight:= N.RightChild;
            OldParentParent:= OldParent.Parent;
            if( OldParentParent <> nil) then begin
               // OldParent has GrandParent. GrandParent gets new child
               if( OldParentParent.LeftChild = OldParent) then
                  OldParentParent.LeftChild:= N
               else
                  OldParentParent.RightChild:= N;
            end else begin
               // OldParent was root node. New root node
               MyRoot:= N;
            end;
            N.Parent:= OldParentParent;
            N.RightChild:= OldParent;
            OldParent.Parent:= N;
            OldParent.LeftChild:= OldRight;
            if( OldRight <> nil) then
               OldRight.Parent:=OldParent;
            N.Balance:= 0;
            OldParent.Balance:= 0;
         end else begin
            // Node.Balance = +1
            // double rotate
            OldParentParent:= OldParent.Parent;
            OldRight:= N.RightChild;
            OldRightLeft:= OldRight.LeftChild;
            OldRightRight:= OldRight.RightChild;
            if( OldParentParent <> nil) then begin
               // OldParent has GrandParent. GrandParent gets new child
               if( OldParentParent.LeftChild = OldParent) then
                  OldParentParent.LeftChild:= OldRight
               else
                  OldParentParent.RightChild:= OldRight;
            end else begin
               // OldParent was root node. new root node
               MyRoot:= OldRight;
            end;
            OldRight.Parent:= OldParentParent;
            OldRight.LeftChild:= N;
            OldRight.RightChild:= OldParent;
            N.Parent:= OldRight;
            N.RightChild:= OldRightLeft;
            OldParent.Parent:= OldRight;
            OldParent.LeftChild:= OldRightRight;
            if( OldRightLeft <> nil) then
               OldRightLeft.Parent:= N;
            if( OldRightRight <> nil) then
               OldRightRight.Parent:= OldParent;
            if( OldRight.Balance <= 0) then
               N.Balance:= 0
            else
               N.Balance:= -1;
            if( OldRight.Balance = -1) then
               OldParent.Balance:= 1
            else
               OldParent.Balance:= 0;
            OldRight.Balance:= 0;
         end;
      end else begin
         // Node is right son
         Inc(OldParent.Balance);
         if( OldParent.Balance = 0) then exit;
         if( OldParent.Balance = +1) then begin
            RebalanceAfterAdd( OldParent);
            exit;
         end;
         // OldParent.Balance = +2
         if( N.Balance = +1) then begin
            // rotate
            OldLeft:= N.LeftChild;
            OldParentParent:= OldParent.Parent;
            if( OldParentParent <> nil) then begin
               // Parent has GrandParent . GrandParent gets new child
               if( OldParentParent.LeftChild = OldParent) then
                  OldParentParent.LeftChild:= N
               else
                  OldParentParent.RightChild:= N;
            end else begin
               // OldParent was root node . new root node
               MyRoot:= N;
            end;
            N.Parent:= OldParentParent;
            N.LeftChild:= OldParent;
            OldParent.Parent:= N;
            OldParent.RightChild:= OldLeft;
            if( OldLeft <> nil) then
               OldLeft.Parent:= OldParent;
            N.Balance:= 0;
            OldParent.Balance:= 0;
         end else begin
            // Node.Balance = -1
            // double rotate
            OldLeft:= N.LeftChild;
            OldParentParent:= OldParent.Parent;
            OldLeftLeft:= OldLeft.LeftChild;
            OldLeftRight:= OldLeft.RightChild;
            if( OldParentParent <> nil) then begin
               // OldParent has GrandParent . GrandParent gets new child
               if( OldParentParent.LeftChild = OldParent) then
                  OldParentParent.LeftChild:= OldLeft
               else
                  OldParentParent.RightChild:= OldLeft;
            end else begin
               // OldParent was root node . new root node
               MyRoot:= OldLeft;
            end;
            OldLeft.Parent:= OldParentParent;
            OldLeft.LeftChild:= OldParent;
            OldLeft.RightChild:= N;
            N.Parent:= OldLeft;
            N.LeftChild:= OldLeftRight;
            OldParent.Parent:= OldLeft;
            OldParent.RightChild:= OldLeftLeft;
            if( OldLeftLeft <> nil) then
               OldLeftLeft.Parent:= OldParent;
            if( OldLeftRight <> nil) then
               OldLeftRight.Parent:= N;
            if( OldLeft.Balance >= 0) then
               N.Balance:= 0
            else
               N.Balance:= +1;
            if(OldLeft.Balance = +1) then
               OldParent.Balance:= -1
            else
               OldParent.Balance:= 0;
            OldLeft.Balance:= 0;
         end;
      end;
   end; // RebalanceAfterAdd()


// ************************************************************************
// * RebalanceAfterRemove() - Rebalance the tree after a Remove()
// ************************************************************************

procedure tgAvlTree.RebalanceAfterRemove( N: tNode);
   var 
      OldParent:         tNode;
      OldRight:          tNode;
      OldRightLeft:      tNode;
      OldLeft:           tNode;
      OldLeftRight:      tNode;
      OldRightLeftLeft:  tNode;
      OldRightLeftRight: tNode;
      OldLeftRightLeft:  tNode;
      OldLeftRightRight: tNode;
   begin
      if( N = nil) then exit;
      if( (N.Balance = +1) or (N.Balance = -1)) then exit;
      OldParent:= N.Parent;
      if( N.Balance = 0) then begin
         // Treeheight has decreased by one
         if(OldParent <> nil) then begin
            if( OldParent.LeftChild = N) then
               Inc( OldParent.Balance)
            else
               Dec( OldParent.Balance);
            RebalanceAfterRemove( OldParent);
         end;
         exit;
      end;
      if( N.Balance = +2) then begin
         // Node is overweighted to the right
         OldRight:= N.RightChild;
         if( OldRight.Balance >= 0) then begin
            // OldRight.Balance=={0 or -1}
            // rotate left
            OldRightLeft := OldRight.LeftChild;
            if( OldParent <> nil) then begin
               if( OldParent.LeftChild = N) then
                  OldParent.LeftChild:= OldRight
               else
                  OldParent.RightChild:= OldRight;
            end else
               MyRoot:= OldRight;
            N.Parent:= OldRight;
            N.RightChild:= OldRightLeft;
            OldRight.Parent:= OldParent;
            OldRight.LeftChild:= N;
            if( OldRightLeft <> nil) then
               OldRightLeft.Parent:= N;
            N.Balance:= (1-OldRight.Balance);
            Dec( OldRight.Balance);
            RebalanceAfterRemove( OldRight);
         end else begin
            // OldRight.Balance=-1
            // double rotate right left
            OldRightLeft:= OldRight.LeftChild;
            OldRightLeftLeft:= OldRightLeft.LeftChild;
            OldRightLeftRight:= OldRightLeft.RightChild;
            if( OldParent <> nil) then begin
               if( OldParent.LeftChild = N) then
                  OldParent.LeftChild:= OldRightLeft
                else
                  OldParent.RightChild:= OldRightLeft;
            end else
               MyRoot:= OldRightLeft;
            N.Parent:= OldRightLeft;
            N.RightChild:= OldRightLeftLeft;
            OldRight.Parent:= OldRightLeft;
            OldRight.LeftChild:= OldRightLeftRight;
            OldRightLeft.Parent:= OldParent;
            OldRightLeft.LeftChild:= N;
            OldRightLeft.RightChild:= OldRight;
            if( OldRightLeftLeft <> nil) then
               OldRightLeftLeft.Parent:= N;
            if( OldRightLeftRight <> nil) then
               OldRightLeftRight.Parent:= OldRight;
            if( OldRightLeft.Balance <= 0) then
               N.Balance:= 0
            else
               N.Balance:= -1;
            if( OldRightLeft.Balance >= 0) then
               OldRight.Balance:= 0
            else
               OldRight.Balance:=+ 1;
            OldRightLeft.Balance:= 0;
            RebalanceAfterRemove( OldRightLeft);
         end;
      end else begin
         // Node.Balance=-2
         // Node is overweighted to the left
         OldLeft:= N.LeftChild;
         if( OldLeft.Balance <= 0) then begin
            // rotate right
            OldLeftRight:= OldLeft.RightChild;
            if (OldParent <> nil) then begin
               if( OldParent.LeftChild = N) then
                  OldParent.LeftChild:= OldLeft
               else
                  OldParent.RightChild:= OldLeft;
            end else
               MyRoot:= OldLeft;
            N.Parent:= OldLeft;
            N.LeftChild:= OldLeftRight;
            OldLeft.Parent:= OldParent;
            OldLeft.RightChild:= N;
            if( OldLeftRight <> nil) then
               OldLeftRight.Parent:= N;
            N.Balance:=( -1 - OldLeft.Balance);
            Inc( OldLeft.Balance);
            RebalanceAfterRemove( OldLeft);
         end else begin
            // OldLeft.Balance = 1
            // double rotate left right
            OldLeftRight:= OldLeft.RightChild;
            OldLeftRightLeft:= OldLeftRight.LeftChild;
            OldLeftRightRight:= OldLeftRight.RightChild;
            if( OldParent <> nil) then begin
               if( OldParent.LeftChild = N) then
                  OldParent.LeftChild:= OldLeftRight
               else
                  OldParent.RightChild:= OldLeftRight;
            end else
               MyRoot:= OldLeftRight;
            N.Parent:= OldLeftRight;
            N.LeftChild:= OldLeftRightRight;
            OldLeft.Parent:= OldLeftRight;
            OldLeft.RightChild:= OldLeftRightLeft;
            OldLeftRight.Parent:= OldParent;
            OldLeftRight.LeftChild:= OldLeft;
            OldLeftRight.RightChild:= N;
            if( OldLeftRightLeft <> nil) then
               OldLeftRightLeft.Parent:= OldLeft;
            if( OldLeftRightRight <> nil) then
               OldLeftRightRight.Parent:= N;
            if( OldLeftRight.Balance >= 0) then
               N.Balance:= 0
            else
               N.Balance:= +1;
            if( OldLeftRight.Balance <=0) then
               OldLeft.Balance:= 0
            else
               OldLeft.Balance:= -1;
            OldLeftRight.Balance:= 0;
            RebalanceAfterRemove( OldLeftRight);
         end;
      end;
   end; // RebalanceAfterRemove()


// ************************************************************************

end. // lbp_generic_trees unit
