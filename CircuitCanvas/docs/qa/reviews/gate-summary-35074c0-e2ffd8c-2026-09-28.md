# テスト結果の要約（ゲート: xcodebuild test）

- 判定: **成功**
- 件数: 96 件（成功 95 / 失敗 0 / 再試行で成功した不安定なテスト 0）
- テスト実行の時間: 865 秒（ビルドを含む全体: 867 秒）
- 端末: iPad Pro 11-inch (M5) TEST (26.5)（並列なし）
- xcodebuild の終了コード: 0

## 遅いテスト（上位 10 件）

| 秒 | テスト |
|---|---|
| 94.8 | `CircuitCanvasUITests/testCircuitCataloguePlacementKindsAndTerminals()` |
| 49.9 | `CircuitCanvasUITests/testBlockPinAdditionAppearsOnEmptySlotsAndTheNewPinWorks()` |
| 46.5 | `CircuitCanvasUITests/testBlockResizeHandlesSnappingLimitsWiresAndReset()` |
| 41.7 | `CircuitCanvasUITests/testUndoStackIsCappedAtTwentySteps()` |
| 40.2 | `CircuitCanvasUITests/testMultiTerminalWiringAdjacentPinsRotationAndMove()` |
| 29.7 | `CircuitCanvasUITests/testUndoRedoOnAddingASymbolANoteAndAWire()` |
| 29.0 | `CircuitCanvasUITests/testNoteResizeHandlesSnappingAndMinimumSize()` |
| 28.2 | `CircuitCanvasUITests/testInspectorRenameAndAnIndependentActionAreSeparateUndoSteps()` |
| 26.0 | `CircuitCanvasUITests/testCircuitWiringSelfRejectionMovementAndGroundDeletion()` |
| 25.3 | `CircuitCanvasUITests/testCircuitRotationControlsPreserveCenterAndWiring()` |

UI テストの所要時間の合計: 845 秒（44 件）。 UI テストは、1 件ごとにアプリを起動し直すため、統合すると起動の回数が減る。

## 全テスト

| 結果 | 秒 | テスト |
|---|---|---|
| Passed | 3.8 | `CircuitCanvasUITests/testBlankCanvasDragCrossingLineRemainsPan()` |
| Passed | 49.9 | `CircuitCanvasUITests/testBlockPinAdditionAppearsOnEmptySlotsAndTheNewPinWorks()` |
| Passed | 46.5 | `CircuitCanvasUITests/testBlockResizeHandlesSnappingLimitsWiresAndReset()` |
| Passed | 94.8 | `CircuitCanvasUITests/testCircuitCataloguePlacementKindsAndTerminals()` |
| Passed | 25.3 | `CircuitCanvasUITests/testCircuitRotationControlsPreserveCenterAndWiring()` |
| Passed | 26.0 | `CircuitCanvasUITests/testCircuitWiringSelfRejectionMovementAndGroundDeletion()` |
| Passed | 7.0 | `CircuitCanvasUITests/testCloseSymbolsRetainMaximumAvailableLead()` |
| Passed | 10.0 | `CircuitCanvasUITests/testDeletingNoteDoesNotCrash()` |
| Passed | 10.8 | `CircuitCanvasUITests/testDeletingSymbolRemovesNewlyAddedWire()` |
| Passed | 8.0 | `CircuitCanvasUITests/testDraggingOneSideOfAStepStraightensTheWire()` |
| Passed | 8.1 | `CircuitCanvasUITests/testEditModeBlocksPlacingASymbolFromTheLibrary()` |
| Passed | 20.5 | `CircuitCanvasUITests/testEditModeGraysOutOtherToolsAndDeletesSymbolsNotesAndWireSegments()` |
| Passed | 12.0 | `CircuitCanvasUITests/testEditModeWireDeletionRemovesOnlyTheTappedSegmentAndKeepsTheRest()` |
| Passed | 6.1 | `CircuitCanvasUITests/testExperimentNoteCanBeDragged()` |
| Passed | 19.2 | `CircuitCanvasUITests/testGenericBlockCanBeRenamedAndGivenAnIconFromTheInspector()` |
| Passed | 9.0 | `CircuitCanvasUITests/testInspectorHasNoRotateOrRelateButtons()` |
| Passed | 28.2 | `CircuitCanvasUITests/testInspectorRenameAndAnIndependentActionAreSeparateUndoSteps()` |
| Passed | 11.2 | `CircuitCanvasUITests/testJunctionsTrackSharedPinsAndSegmentDrags()` |
| Passed | 40.2 | `CircuitCanvasUITests/testMultiTerminalWiringAdjacentPinsRotationAndMove()` |
| Passed | 18.3 | `CircuitCanvasUITests/testNoteInspectorIsRenamedHasAMemoTypeAndAnIconPicker()` |
| Passed | 19.2 | `CircuitCanvasUITests/testNoteRelateButtonWorksWithoutOpeningTheInspector()` |
| Passed | 29.0 | `CircuitCanvasUITests/testNoteResizeHandlesSnappingAndMinimumSize()` |
| Passed | 15.7 | `CircuitCanvasUITests/testOperationHintStaysFixedDuringZoomAndPan()` |
| Passed | 10.1 | `CircuitCanvasUITests/testPinCentersMatchAndWireEndpointsFollowBothDraggedSymbols()` |
| Passed | 17.8 | `CircuitCanvasUITests/testRequestedRoutesAndSymbolMovementAvoidBodiesAndOverlaps()` |
| Passed | 10.6 | `CircuitCanvasUITests/testSegmentDragKeepsEndpointsViewportCountAndManualPosition()` |
| Passed | 5.0 | `CircuitCanvasUITests/testSegmentDragStopsAtBodyBoundary()` |
| Passed | 15.7 | `CircuitCanvasUITests/testSettingsCanRenameCanvasAndEditAMultilineDescription()` |
| Passed | 13.2 | `CircuitCanvasUITests/testSettingsResetCancelledLeavesTheCanvasUntouched()` |
| Passed | 14.2 | `CircuitCanvasUITests/testSettingsResetConfirmedClearsSymbolsWiresAndNotes()` |
| Passed | 23.1 | `CircuitCanvasUITests/testShortHorizontalLineDragsAndCrossings()` |
| Passed | 15.7 | `CircuitCanvasUITests/testStartPinSelectionResetsAndIsReusedWithoutStrayWires()` |
| Passed | 7.5 | `CircuitCanvasUITests/testTappingTheBackgroundWhilePickingARelateCornerCancelsInsteadOfLeavingTheHintStuck()` |
| Passed | 10.4 | `CircuitCanvasUITests/testUndoRedoOnASymbolMoveAndAfterANewOperationRedoIsCleared()` |
| Passed | 29.7 | `CircuitCanvasUITests/testUndoRedoOnAddingASymbolANoteAndAWire()` |
| Passed | 15.2 | `CircuitCanvasUITests/testUndoRedoOnDeletingAConnectedSymbolRestoresWireEndpointsAndRoutes()` |
| Passed | 11.9 | `CircuitCanvasUITests/testUndoRedoOnWireSegmentDeletionStaysAvailableDuringEditMode()` |
| Passed | 41.7 | `CircuitCanvasUITests/testUndoStackIsCappedAtTwentySteps()` |
| Passed | 17.5 | `CircuitCanvasUITests/testVerticalPowerSegmentDragBranchAndRotation()` |
| Passed | 13.6 | `CircuitCanvasUITests/testWireToolConnectsPinsAndRejectsDuplicatesBothWays()` |
| Passed | 17.3 | `CircuitCanvasUITests/testZoomMenuKeepsTheViewportCenterEvenWhenAlreadyPannedNearTheEdge()` |
| Skipped | 6.5 | `CircuitCanvasUITests/testZoomMenuLandsExactlyOnAPresetAfterAPinchToANonPresetScale()` |
| Passed | 7.8 | `CircuitCanvasUITests/testZoomMenuLandsExactlyOnAPresetFromAnInjectedNonPresetStartingScale()` |
| Passed | 22.3 | `CircuitCanvasUITests/testZoomMenuOffersFixedPercentagesAndAppliesThemExactly()` |
| Passed | 0.0 | `CircuitSymbolTests/addPinIndicatorNeverOverlapsAPinOrAResizeHandleAtAnyZoom()` |
| Passed | 0.0 | `CircuitSymbolTests/addedBlockPinsSitOnTheirRowAndLeadOutward()` |
| Passed | 0.0 | `CircuitSymbolTests/blockPinSlotsCoverOneLeftAndRightPerThirtyPointRow()` |
| Passed | 0.0 | `CircuitSymbolTests/blockPinsUseTheFirstRowSlotAndBodiesFollowTheSize()` |
| Passed | 0.0 | `CircuitSymbolTests/blockSizesSnapToThirtyPointStepsWithinLimits()` |
| Passed | 0.0 | `CircuitSymbolTests/canvasZoomKeepsTheViewportCenterOnTheSameCanvasPointEvenWhenPannedNearAnEdge()` |
| Passed | 0.0 | `CircuitSymbolTests/catalogueCategoriesAndVectorGeometry()` |
| Passed | 0.0 | `CircuitSymbolTests/defaultPowerOrientationsAndUprightLetters()` |
| Passed | 0.0 | `CircuitSymbolTests/draggingACornerKeepsTheOppositeCornerFixed()` |
| Passed | 0.0 | `CircuitSymbolTests/externalLeadsAreFifteenPointsExceptNarrowPlateSymbols()` |
| Passed | 0.0 | `CircuitSymbolTests/minimumBlockHeightGrowsWithTheDeepestAddedPin()` |
| Passed | 0.0 | `CircuitSymbolTests/multiTerminalPinLayoutsMatchTheSpecification()` |
| Passed | 0.0 | `CircuitSymbolTests/multiTerminalShapesReachEveryPin()` |
| Passed | 0.0 | `CircuitSymbolTests/pinsBodyAndOutwardDirectionsForEveryKindAndRotation()` |
| Passed | 0.0 | `CircuitSymbolTests/plateSymbolsKeepTheirPlatesClose()` |
| Passed | 0.0 | `CircuitSymbolTests/resizeHandlesAreFingerSizedAndClearOfPinsAtEveryZoom()` |
| Passed | 0.0 | `CircuitSymbolTests/screenConstantGrowsBelowFullZoomAndNeverShrinksAboveIt()` |
| Passed | 0.0 | `CircuitSymbolTests/twoTerminalAndSingleTerminalSymbolsKeepTheirOriginalPinOrder()` |
| Passed | 0.0 | `CircuitSymbolTests/wireEndsFollowTheirOwnPinWhenNewPinsCoincideWithOldOnes()` |
| Passed | 0.0 | `WireRoutingTests/aKeptWireThatNowOverlapsAManualRouteIsPlannedAgain()` |
| Passed | 0.0 | `WireRoutingTests/aStraightenedManualRouteStillFollowsItsMovedEnds()` |
| Passed | 0.0 | `WireRoutingTests/aStraightenedRouteHasNoZeroLengthOrCollinearSegments()` |
| Passed | 0.0 | `WireRoutingTests/aWireThatABodyNowSitsOnIsRoutedAgainAndOthersStay()` |
| Passed | 0.0 | `WireRoutingTests/backgroundHitResolutionRejectsBlankSpaceAndTerminalLeads()` |
| Passed | 0.0 | `WireRoutingTests/closeBodiesUseHalfGapForLeadsAndClearance()` |
| Passed | 0.0 | `WireRoutingTests/crossingTouchUsesPerpendicularMotionForReturnDrag()` |
| Passed | 0.0 | `WireRoutingTests/crossingsExcludeCornersBranchesAndRecomputeAfterMovement()` |
| Passed | 0.0 | `WireRoutingTests/draggingOneSideOfAStepOntoTheOtherMakesOneStraightSegment()` |
| Passed | 0.0 | `WireRoutingTests/firstRoutingPlansEveryWireInOrderAndLaterRoutingKeepsUnrelatedOnes()` |
| Passed | 0.8 | `WireRoutingTests/fuzzedMovesResizesRotationsAndDragsNeverProduceADiagonalWire(seed:)` |
| Passed | 0.1 | `WireRoutingTests/initialAndRequestedRoutesAvoidBodiesAndOverlaps()` |
| Passed | 0.0 | `WireRoutingTests/junctionsDeduplicateMultipleBranchesAndExcludePinsAndCrossings()` |
| Passed | 0.0 | `WireRoutingTests/manualRoutesAreReattachedNotReplanned()` |
| Passed | 0.0 | `WireRoutingTests/manualSegmentPositionSurvivesEndpointMovement()` |
| Passed | 0.0 | `WireRoutingTests/overlapIsAllowedOnlyAlongTheTrunkOfASharedPin()` |
| Passed | 0.0 | `WireRoutingTests/rerouteReplacesAKeptRouteThatIsNotOrthogonal()` |
| Passed | 0.0 | `WireRoutingTests/rotatedPinsRouteOutwardAvoidBodiesAndShareOnlyTerminalTrunks()` |
| Passed | 0.0 | `WireRoutingTests/routesThroughNarrowGapsStayDraggableAndStillAvoidBodies()` |
| Passed | 0.0 | `WireRoutingTests/segmentDragIsPerpendicularAttachedAndCannotTunnelThroughBody()` |
| Passed | 0.0 | `WireRoutingTests/shortHorizontalDragCreatesAndRemovesCrossingOnOtherWire()` |
| Passed | 0.0 | `WireRoutingTests/shortHorizontalTouchChoosesVisibleLineAndMovesOnlyItsY()` |
| Passed | 0.0 | `WireRoutingTests/snapReachesExactlyThirteenPointsAndNoFurther()` |
| Passed | 0.0 | `WireRoutingTests/snappingNeverPullsASegmentThroughABody()` |
| Passed | 0.0 | `WireRoutingTests/splittingAMiddleSegmentKeepsBothRemainingSidesSeparately()` |
| Passed | 0.0 | `WireRoutingTests/splittingAnOutOfRangeSegmentKeepsTheOriginalPathAsTheFrontSide()` |
| Passed | 0.0 | `WireRoutingTests/splittingTheFirstSegmentKeepsOnlyTheRemainingBackSide()` |
| Passed | 0.0 | `WireRoutingTests/splittingTheLastSegmentKeepsOnlyTheRemainingFrontSide()` |
| Passed | 0.0 | `WireRoutingTests/splittingTheOnlySegmentOfAStraightWireLeavesNothingOnEitherSide()` |
| Passed | 0.0 | `WireRoutingTests/tightLayoutsStillDrawAnOrthogonalWire()` |
| Passed | 0.0 | `WireRoutingTests/verticalTerminalManualDragAndReattachment()` |
| Passed | 0.0 | `WireRoutingTests/wireIsStillDrawnWhenNoPlannedRouteExists()` |
| Passed | 0.0 | `WireRoutingTests/wireLeavesTheFirstRowSlotOfATallBlockSideways()` |
