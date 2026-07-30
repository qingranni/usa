// GlassPill.tsx — Glass pill component (dock pill + follow-up entry)
// Matches GlassPill.swift behavior: glass capsule with animated loading state
import React from 'react';
import { Theme } from '../theme/theme';

interface GlassPillProps {
  text?: string;
  loading?: boolean;
  onClick?: () => void;
  variant?: 'home' | 'followup';
  className?: string;
  style?: React.CSSProperties;
}

export const GlassPill: React.FC<GlassPillProps> = ({
  text = 'Ask anything',
  loading = false,
  onClick,
  variant = 'followup',
  className,
  style,
}) => {
  return (
    <button
      className={`glass-pill ${className ?? ''}`}
      onClick={onClick}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        padding: variant === 'home' ? '14px 28px' : '12px 22px',
        cursor: 'pointer',
        transition: `transform 80ms ease-out, box-shadow 80ms ease-out`,
        ...style,
      }}
      onMouseDown={e => {
        (e.currentTarget as HTMLButtonElement).style.transform = 'scale(0.97)';
      }}
      onMouseUp={e => {
        (e.currentTarget as HTMLButtonElement).style.transform = 'scale(1)';
      }}
      onMouseLeave={e => {
        (e.currentTarget as HTMLButtonElement).style.transform = 'scale(1)';
      }}
    >
      {/* Search icon */}
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" style={{ opacity: 0.5, flexShrink: 0 }}>
        <circle cx="11" cy="11" r="7" stroke={Theme.ink} strokeWidth="2.2"/>
        <path d="M16.5 16.5L21 21" stroke={Theme.ink} strokeWidth="2.2" strokeLinecap="round"/>
      </svg>

      {loading ? (
        <LoadingDots />
      ) : (
        <span style={{
          fontSize: variant === 'home' ? 16 : 15,
          fontWeight: 500,
          color: Theme.inkMuted,
          letterSpacing: '-0.01em',
          whiteSpace: 'nowrap',
        }}>
          {text}
        </span>
      )}

      {/* Mic icon */}
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" style={{ opacity: 0.4, flexShrink: 0, marginLeft: 'auto' }}>
        <rect x="9" y="2" width="6" height="13" rx="3" stroke={Theme.ink} strokeWidth="2.2"/>
        <path d="M5 11c0 3.866 3.134 7 7 7s7-3.134 7-7" stroke={Theme.ink} strokeWidth="2.2" strokeLinecap="round"/>
        <line x1="12" y1="18" x2="12" y2="22" stroke={Theme.ink} strokeWidth="2.2" strokeLinecap="round"/>
      </svg>
    </button>
  );
};

const LoadingDots: React.FC = () => (
  <span style={{ display: 'flex', gap: 4, alignItems: 'center' }}>
    {[0, 1, 2].map(i => (
      <span
        key={i}
        style={{
          width: 5,
          height: 5,
          borderRadius: '50%',
          background: Theme.inkMuted,
          animation: `loadingDot 1.2s ease-in-out ${i * 0.2}s infinite`,
        }}
      />
    ))}
    <style>{`
      @keyframes loadingDot {
        0%, 80%, 100% { transform: scale(0.6); opacity: 0.4; }
        40% { transform: scale(1); opacity: 1; }
      }
    `}</style>
  </span>
);

interface GlassCircleButtonProps {
  icon: 'home' | 'back' | 'trips' | 'close' | 'history';
  size?: number;
  onClick?: () => void;
  style?: React.CSSProperties;
}

export const GlassCircleButton: React.FC<GlassCircleButtonProps> = ({
  icon,
  size = 44,
  onClick,
  style,
}) => {
  return (
    <button
      className="glass-pill"
      onClick={onClick}
      style={{
        width: size,
        height: size,
        borderRadius: '50%',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0,
        transition: `transform 80ms ease-out`,
        ...style,
      }}
      onMouseDown={e => {
        (e.currentTarget as HTMLButtonElement).style.transform = 'scale(0.93)';
      }}
      onMouseUp={e => {
        (e.currentTarget as HTMLButtonElement).style.transform = 'scale(1)';
      }}
      onMouseLeave={e => {
        (e.currentTarget as HTMLButtonElement).style.transform = 'scale(1)';
      }}
    >
      <ButtonIcon icon={icon} />
    </button>
  );
};

const ButtonIcon: React.FC<{ icon: GlassCircleButtonProps['icon'] }> = ({ icon }) => {
  const style = { opacity: 0.7 };
  if (icon === 'home') return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" style={style}>
      <path d="M3 12L12 3l9 9" stroke={Theme.ink} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
      <path d="M5 10v9a1 1 0 001 1h4v-5h4v5h4a1 1 0 001-1v-9" stroke={Theme.ink} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  );
  if (icon === 'back') return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" style={style}>
      <path d="M19 12H5M12 19l-7-7 7-7" stroke={Theme.ink} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  );
  if (icon === 'trips') return (
    <svg width="17" height="17" viewBox="0 0 24 24" fill="none" style={style}>
      <circle cx="12" cy="12" r="9" stroke={Theme.ink} strokeWidth="2"/>
      <path d="M12 7v5l3 3" stroke={Theme.ink} strokeWidth="2" strokeLinecap="round"/>
    </svg>
  );
  if (icon === 'close') return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" style={style}>
      <path d="M18 6L6 18M6 6l12 12" stroke={Theme.ink} strokeWidth="2.2" strokeLinecap="round"/>
    </svg>
  );
  if (icon === 'history') return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" style={style}>
      <path d="M3 12a9 9 0 109-9 9 9 0 00-9 9z" stroke={Theme.ink} strokeWidth="2"/>
      <path d="M12 7v5l4 2" stroke={Theme.ink} strokeWidth="2" strokeLinecap="round"/>
    </svg>
  );
  return null;
};
