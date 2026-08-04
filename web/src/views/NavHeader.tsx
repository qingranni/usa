// NavHeader.tsx — Global navigation header
// Port of NavHeader.swift: opacity crossfade back/history buttons by reveal stage,
// title crossfade, positioned above the shrunken canvas (unscaled).

import React from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useAppStore, stageResults, stageTrip, selectOpenThread } from '../store/appStore';
import { GlassCircleButton } from '../components/GlassPill';
import { Theme } from '../theme/theme';
import { progress, eased, lerp } from '../morph/morphProgress';

const NavHeader: React.FC = () => {
  const {
    reveal,
    setReveal,
    dismissCanvasToHome,
    openThreadByID,
    lastOpenThreadID,
  } = useAppStore();

  const thread = useAppStore(selectOpenThread);

  // Back button opacity: visible at stage 0 (results)
  const backOpacity = lerp(1, 0, eased(progress(reveal, 0, 0.5)));
  // History button opacity: fades in at trip stage
  const historyOpacity = lerp(0, 1, eased(progress(reveal, 1.5, 2)));

  const handleBack = () => {
    if (reveal > 0) {
      setReveal(stageResults);
    } else {
      dismissCanvasToHome();
    }
  };

  const handleHistory = () => {
    if (lastOpenThreadID) {
      openThreadByID(lastOpenThreadID);
    }
  };

  return (
    <div style={{
      position: 'absolute',
      top: 0,
      left: 0,
      right: 0,
      height: 64,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      paddingInline: 20,
      paddingTop: 8,
      zIndex: 20,
      pointerEvents: 'none',
    }}>
      {/* Left: empty slot (history moved to SearchResultsView header) */}
      <div style={{ width: 44, height: 44 }} />

      {/* Center: thread title crossfade */}
      <div style={{
        flex: 1,
        textAlign: 'center',
        paddingInline: 12,
        pointerEvents: 'none',
      }}>
        <AnimatePresence mode="wait">
          <motion.div
            key={thread?.title ?? 'empty'}
            initial={{ opacity: 0, y: -6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 6 }}
            transition={{ duration: 0.18, ease: 'easeInOut' }}
            style={{
              fontSize: 15,
              fontWeight: 700,
              color: Theme.ink,
              letterSpacing: '-0.015em',
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {thread?.title ?? ''}
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Right: empty spacer */}
      <div style={{ width: 44, height: 44 }} />
    </div>
  );
};

export default NavHeader;
