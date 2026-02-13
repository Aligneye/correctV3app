import { useState } from 'react';
import { HomeDashboard } from './components/home-dashboard';
import { ModeSelection } from './components/mode-selection';
import { TrainingMode } from './components/training-mode';
import { TherapyMode } from './components/therapy-mode';
import { MeditationMode } from './components/meditation-mode';
import { AnalyticsScreen } from './components/analytics-screen';
import { DeviceSettings } from './components/device-settings';
import { Home, Activity, BarChart3, Settings } from 'lucide-react';

export type Screen = 'home' | 'modes' | 'training' | 'therapy' | 'meditation' | 'analytics' | 'settings';

export default function App() {
    const [currentScreen, setCurrentScreen] = useState<Screen>('home');

    const renderScreen = () => {
        switch (currentScreen) {
            case 'home':
                return <HomeDashboard onNavigate={setCurrentScreen} />;
            case 'modes':
                return <ModeSelection onNavigate={setCurrentScreen} />;
            case 'training':
                return <TrainingMode onBack={() => setCurrentScreen('modes')} />;
            case 'therapy':
                return <TherapyMode onBack={() => setCurrentScreen('modes')} />;
            case 'meditation':
                return <MeditationMode onBack={() => setCurrentScreen('modes')} />;
            case 'analytics':
                return <AnalyticsScreen onBack={() => setCurrentScreen('home')} />;
            case 'settings':
                return <DeviceSettings onBack={() => setCurrentScreen('home')} />;
            default:
                return <HomeDashboard onNavigate={setCurrentScreen} />;
        }
    };

    return (
        <div className="min-h-screen bg-gradient-to-br from-slate-50 via-blue-50 to-purple-50">
            {/* Mobile App Container */}
            <div className="max-w-md mx-auto min-h-screen bg-white shadow-2xl relative overflow-hidden">
                {/* Screen Content */}
                <div className="pb-20">
                    {renderScreen()}
                </div>

                {/* Bottom Navigation */}
                <nav className="fixed bottom-0 left-0 right-0 max-w-md mx-auto bg-white/80 backdrop-blur-xl border-t border-gray-200/50 px-6 py-3">
                    <div className="flex items-center justify-around">
                        <button
                            onClick={() => setCurrentScreen('home')}
                            className={`flex flex-col items-center gap-1 px-4 py-2 rounded-xl transition-all ${currentScreen === 'home'
                                ? 'text-blue-600'
                                : 'text-gray-400'
                                }`}
                        >
                            <Home className="w-6 h-6" />
                            <span className="text-xs">Home</span>
                        </button>
                        <button
                            onClick={() => setCurrentScreen('modes')}
                            className={`flex flex-col items-center gap-1 px-4 py-2 rounded-xl transition-all ${currentScreen === 'modes' || currentScreen === 'training' || currentScreen === 'therapy' || currentScreen === 'meditation'
                                ? 'text-blue-600'
                                : 'text-gray-400'
                                }`}
                        >
                            <Activity className="w-6 h-6" />
                            <span className="text-xs">Modes</span>
                        </button>
                        <button
                            onClick={() => setCurrentScreen('analytics')}
                            className={`flex flex-col items-center gap-1 px-4 py-2 rounded-xl transition-all ${currentScreen === 'analytics'
                                ? 'text-blue-600'
                                : 'text-gray-400'
                                }`}
                        >
                            <BarChart3 className="w-6 h-6" />
                            <span className="text-xs">Analytics</span>
                        </button>
                        <button
                            onClick={() => setCurrentScreen('settings')}
                            className={`flex flex-col items-center gap-1 px-4 py-2 rounded-xl transition-all ${currentScreen === 'settings'
                                ? 'text-blue-600'
                                : 'text-gray-400'
                                }`}
                        >
                            <Settings className="w-6 h-6" />
                            <span className="text-xs">Settings</span>
                        </button>
                    </div>
                </nav>
            </div>
        </div>
    );
}
