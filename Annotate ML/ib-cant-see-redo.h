//
//  ib-cant-see-redo.h
//  Annotate ML
//
//  Created by Emily Blackwell on 14/11/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

#ifndef ib_cant_see_redo_h
#define ib_cant_see_redo_h

#import <Cocoa/Cocoa.h>

// https://stackoverflow.com/questions/14361298/firstresponder-missing-redo
@interface NSResponder (Redo)
- (IBAction) redo:(id)sender;
@end

#endif /* ib_cant_see_redo_h */
